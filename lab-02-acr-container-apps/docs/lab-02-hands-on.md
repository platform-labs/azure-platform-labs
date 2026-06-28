# Azure Hands-on Lab #2

## Deliberate practice loop

1. **Mental model:** vẽ source → Docker image → ACR → Task Definition → Container Apps Service → ALB → target.
2. **Console discovery:** lượt đầu tạo ACR/Container Apps/ALB bằng Console; lượt sau map từng màn hình với Terraform/API.
3. **Implementation:** build/test local, push image, tạo roles, cluster, task definition, ALB và service.
4. **CLI verification:** query service desired/running count, task ENI, target health, image digest và Azure Monitor logs.
5. **Failure drill:** deploy image tag không tồn tại hoặc đổi health path sai; phân biệt task startup failure với target unhealthy.
6. **Rebuild without guide:** từ source code trống deployment, tự build → push → service stable.
7. **Cleanup/cost audit:** xóa Container Apps service và ALB trước; kiểm tra ACR images, ENI và log group.
8. **Interview recap:** giải thích Task Role/Execution Role, `awsvpc`, target type `ip` và self-healing.

Quy tắc luyện nhiều vòng: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

## Dockerize WalletMinimal → ACR → Azure Container Apps → ALB → Azure Monitor

### Mục tiêu

Sau lab này cần hiểu được:

* Docker image cho ASP.NET Core
* ACR (Elastic Container Registry)
* Azure Container Apps (serverless container)
* Task Definition / Service / Cluster
* Application Load Balancer (ALB)
* Azure Monitor Logs cho container (không cần cài Agent)

Đây là bước tiếp theo sau Lab #1 — chuyển từ "Azure VM chạy app trực tiếp" sang "container orchestration serverless", mô hình rất phổ biến ở các công ty Azure trước khi cần đến AKS.

---

# Tại sao Azure Container Apps trước AKS?

| | Azure Container Apps | AKS |
| - | ----------- | --- |
| Control plane | Azure quản lý, không trả phí riêng | $0.10/giờ cho control plane |
| Node quản lý | Không cần — serverless, Azure tự scale | Cần quản lý node group hoặc Container Apps profile |
| Learning curve | Thấp — chỉ cần hiểu Task Definition | Cao — cần hiểu kubectl, manifests, RBAC |
| Phù hợp | Team nhỏ, ít service, muốn ship nhanh | Team lớn, nhiều service, cần K8s ecosystem |
| Anh đã biết K8s | Đây là điều **mới** cần học — Azure-native orchestration | Đã quen self-hosted K8s trên Proxmox |

> **Insight:** Rất nhiều công ty dùng Azure chọn Azure Container Apps vì đơn giản hơn, rẻ hơn ở quy mô nhỏ-vừa, và không cần một đội riêng vận hành control plane. AKS đáng dùng khi đã có nhiều cluster/multi-cloud hoặc cần K8s ecosystem (Helm, Operators...). So sánh trực tiếp với CSNP (self-hosted K8s trên Proxmox) sẽ thấy rõ trade-off.

---

# Architecture

```text
                          Internet
                              |
                              v
                    Application Load Balancer
                         (csnp-wallet-alb)
                              |
                              v
                       Target Group :5000
                              |
                              v
                    Azure Container Apps Service
                    (csnp-wallet-service)
                              |
              +---------------+---------------+
              |                               |
              v                               v
        Container Apps Task 1                  Container Apps Task 2
        (container :5000)               (container :5000)
              |                               |
              +---------------+---------------+
                              |
                 +------------+------------+
                 |                         |
                 v                         v
          Azure Database for PostgreSQL Flexible Server                Azure Blob Storage Bucket
          (csnp-wallet-dev)         (csnp-wallet-dev)
                              |
                              v
                      Azure Monitor Logs
                   (/ecs/csnp-wallet-api)
```

---

# Prerequisites

* Đã hoàn thành Lab #1 (Azure VM + Azure Database for PostgreSQL + Azure Blob Storage + Managed Identity + Azure Monitor)
* Azure Database for PostgreSQL `csnp-wallet-dev` đang chạy (giữ lại từ Lab 1)
* Azure Blob Storage bucket `csnp-wallet-dev` đang có (giữ lại từ Lab 1)
* Docker Desktop cài trên máy local (Windows + WSL2 backend)
* Azure CLI đã configure (`aws configure` hoặc dùng Microsoft Entra ID / Azure RBAC user có quyền ACR/Container Apps)

> **Lưu ý:** Azure VM từ Lab 1 không cần thiết cho Lab 2 — có thể terminate nếu muốn tiết kiệm, vì Azure Container Apps sẽ thay thế vai trò compute. Giữ Azure Database for PostgreSQL và Azure Blob Storage vì 2 cái này vẫn dùng chung.

---

# Cost Warning

| Resource | Chi phí ước tính | Ghi chú |
| -------- | ----------------- | ------- |
| ACR | $0.10/GB/tháng lưu trữ | Image vài chục MB, không đáng kể |
| Azure Container Apps | ~$0.04/giờ cho 0.25 vCPU + 0.5GB | Tính theo task đang chạy |
| ALB | ~$16/tháng + $0.008/LCU-giờ | **Tốn nhất trong lab này** |
| Data transfer | Free Tier 100GB/tháng | Đủ dùng cho lab |

> **Quan trọng:** ALB là resource tốn tiền nhất trong lab này, tính theo giờ kể cả khi không có traffic. Nhớ xóa ALB ngay sau khi xong lab (xem phần Cleanup).

---

# Step 1 - Dockerize WalletMinimal

## Tạo Dockerfile

Trong thư mục `WalletMinimal` (từ Lab 1), tạo file `Dockerfile`:

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY *.csproj .
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000

ENTRYPOINT ["dotnet", "Lab02.WalletMinimal.dll"]
```

> **Multi-stage build:** Stage `build` dùng SDK image (nặng, có compiler) chỉ để build. Stage `runtime` dùng ASP.NET runtime image (nhẹ hơn nhiều) để chạy. Image cuối cùng không có source code hay SDK, chỉ có binary đã publish — nhỏ gọn và bảo mật hơn.

## Tạo .dockerignore

```text
bin/
obj/
publish/
*.user
.vs/
```

## Build image local để test

### Tại sao cần build local?

Trước khi đẩy image lên ACR và deploy lên Container Apps, nên test Docker image chạy đúng ở máy local hoặc trên một Azure VM tạm. Điều này giúp:

* **Verify Dockerfile syntax** — catch lỗi build sớm
* **Test environment variables** — app đọc config đúng không?
* **Verify runtime** — app start, endpoint response đúng không?
* **Save CI/CD time** — không phải build lại lên ACR nếu lỗi cơ bản

### Option 1: Build trên máy local (Docker Desktop)

Nếu cài Docker Desktop (Windows + WSL2):

```bash
# Từ thư mục Lab02.WalletMinimal
cd ./lab-02-acr-container-apps/src/Lab02.WalletMinimal

docker build -t wallet-api:local .

# Verify image được tạo
docker images | grep wallet-api
```

### Option 2: Build trên Azure VM (recommended cho lab)

Nếu không có Docker Desktop, tạo một Azure VM tạm để build:

```bash
# 1. SSH vào Azure VM (reuse từ Lab 1 hoặc tạo t3.micro tạm)
ssh -i "C:\Users\Toan\.ssh\wallet-dev-key.pem" ec2-user@Azure VM-PUBLIC-IP
```

```bash
# 2. Cài Docker trên Azure VM
sudo dnf update -y
sudo dnf install -y docker

sudo systemctl enable docker
sudo systemctl start docker

# 3. Thêm ec2-user vào docker group (để không cần sudo)
sudo usermod -aG docker ec2-user
newgrp docker

# 4. Verify Docker hoạt động
docker ps
```

```powershell
# 5. (Từ máy local PowerShell) Copy source code lên Azure VM
scp -i "C:\Users\Toan\.ssh\wallet-dev-key.pem" `
    -r ./lab-02-acr-container-apps/src/Lab02.WalletMinimal `
    ec2-user@Azure VM-PUBLIC-IP:/home/ec2-user/Lab02.WalletMinimal
```

```bash
# 6. (SSH Azure VM tiếp tục) Build image
cd /home/ec2-user/Lab02.WalletMinimal
docker build -t wallet-api:local .

# Verify
docker images | grep wallet-api
```

### Test chạy container local trước khi đẩy lên Azure

Chạy container từ image vừa build:

```bash
docker run -d -p 5000:5000 \
  -e DB_HOST=<Azure Database for PostgreSQL-ENDPOINT> \
  -e DB_PORT=5432 \
  -e DB_NAME=wallet \
  -e DB_USER=postgres \
  -e DB_PASSWORD=<your-password> \
  -e Azure Blob Storage_BUCKET=csnp-wallet-dev \
  -e Azure_REGION=eastus \
  --name wallet-api-test \
  wallet-api:local
```

> **⚠️ Quan trọng - Managed Identity vs Access Key:**
>
> Test local cần **Access Key tạm thời** vì máy local/Azure VM test không có Microsoft Entra ID / Azure RBAC Task Role (Task Role chỉ tồn tại khi deploy lên Container Apps).
>
> **Điều này là ngoại lệ duy nhất** trong toàn bộ lab:
> * Lab 1 (Azure VM): dùng Microsoft Entra ID / Azure RBAC Instance Role ✅ (best practice)
> * Lab 2 local test: dùng Access Key tạm ⚠️ (necessary for testing)
> * Lab 2 Container Apps (Step 5): dùng Microsoft Entra ID / Azure RBAC Task Role ✅ (best practice)
>
> **Sau khi test xong, revoke Access Key tạm này** ở Microsoft Entra ID / Azure RBAC console.

### Verify container chạy đúng

```bash
# 1. Check container đang chạy
docker ps | grep wallet-api

# 2. Test health endpoint
curl http://localhost:5000/health
# Expected: {"status":"ok","time":"2026-06-19T...Z"}

# 3. Test list wallets (empty list từ Azure Database for PostgreSQL)
curl http://localhost:5000/wallets
# Expected: []

# 4. Test create wallet
curl -X POST http://localhost:5000/wallets \
  -H "Content-Type: application/json" \
  -d '{"ownerId":"user-001","balance":1000}'
# Expected: 201 Created với wallet object

# 5. Test Azure Blob Storage upload endpoint
curl -X POST http://localhost:5000/upload
# Expected: 200 OK với file uploaded to Azure Blob Storage

# 6. Stop & remove container
docker stop wallet-api-test
docker rm wallet-api-test
```

### Troubleshooting Build/Run

| Lỗi | Nguyên nhân | Cách sửa |
| --- | --- | --- |
| `dotnet: command not found` | .NET Runtime chưa cài trên Azure VM | Cài `sudo dnf install -y dotnet-sdk-10.0` hoặc dùng local build |
| `docker: permission denied` | `ec2-user` không trong docker group | Chạy `sudo usermod -aG docker ec2-user` và `newgrp docker` |
| `Connection refused :5000` | Container chưa start hoặc failed | Check `docker logs wallet-api-test` |
| `DB connection timeout` | Azure Database for PostgreSQL endpoint sai hoặc Azure Database for PostgreSQL security group block | Verify Azure Database for PostgreSQL endpoint, check Azure Database for PostgreSQL SG inbound rule cho Azure VM SG |
| `Azure Blob Storage access denied` | Access Key không có quyền Azure Blob Storage | Verify Access Key policy có `s3:GetObject`, `s3:PutObject` |

---

# Step 2 - Tạo ACR Repository

## Tạo Repository

ACR → Repositories → Create repository

| Field | Value |
| ----- | ----- |
| Visibility | Private |
| Repository name | csnp-wallet-api |
| Tag immutability | Disabled (lab thôi, production nên Enable) |
| Scan on push | Enable (free, quét lỗ hổng cơ bản) |

## Push Image lên ACR

Microsoft Entra ID / Azure RBAC → Roles → csnp-api-role

AmazonAzure VMContainerRegistryPowerUser

Lấy login command:

```bash
aws ecr get-login-password --region eastus | \
  docker login --username Azure --password-stdin <ACCOUNT-ID>.dkr.ecr.eastus.amazonaws.com
```

Tag và push:

```bash
docker tag wallet-api:local <ACCOUNT-ID>.dkr.ecr.eastus.amazonaws.com/csnp-wallet-api:v1

docker push <ACCOUNT-ID>.dkr.ecr.eastus.amazonaws.com/csnp-wallet-api:v1
```

Verify trên console:

```text
ACR → csnp-wallet-api → Images → thấy tag v1
```

---

# Step 3 - Tạo Managed Identitys cho Container Apps

Azure Container Apps cần **2 role riêng biệt**, khác với Azure VM chỉ cần 1 role:

| Role | Mục đích | Ai dùng |
| ---- | -------- | ------- |
| **Task Execution Role** | Cho phép Container Apps pull image từ ACR, ghi log lên Azure Monitor | Container Apps Agent (hạ tầng) |
| **Task Role** | Cho phép container code gọi Azure Blob Storage, giống Managed Identity ở Lab 1 | App code bên trong container |

> **Phân biệt quan trọng:** Task Execution Role là quyền của hạ tầng Container Apps để khởi động container. Task Role là quyền của chính ứng dụng đang chạy bên trong container. Đây là khái niệm không tồn tại ở Lab 1 vì Azure VM chỉ có 1 Instance Role duy nhất.

## Tạo Task Execution Role

Microsoft Entra ID / Azure RBAC → Roles → Create Role

```text
Trusted entity: Azure Service → Elastic Container Service → Elastic Container Service Task
Policy: AmazonContainer AppsTaskExecutionRolePolicy
Role name: csnp-ecs-execution-role
```

## Tạo Task Role

Microsoft Entra ID / Azure RBAC → Roles → Create Role

```text
Trusted entity: Azure Service → Elastic Container Service → Elastic Container Service Task
Policy: AmazonAzure Blob StorageFullAccess (giống Lab 1, dùng cho /upload endpoint)
Role name: csnp-ecs-task-role
```

---

# Step 4 - Tạo Container Apps Cluster

Container Apps → Clusters → Create Cluster

| Field | Value |
| ----- | ----- |
| Cluster name | csnp-wallet-cluster |
| Infrastructure | Azure Container Apps (serverless) |

> Không chọn Azure VM Linux/Windows — đó là self-managed capacity, phải tự quản lý instance. Container Apps serverless nghĩa là Azure tự cấp phát compute cho từng task.

---

# Step 5 - Tạo Task Definition

Container Apps → Task Definitions → Create new Task Definition

## Task Configuration

| Field | Value |
| ----- | ----- |
| Task definition family | csnp-wallet-api |
| Launch type | Azure Container Apps |
| OS/Architecture | Linux/X86_64 |
| CPU | 0.25 vCPU |
| Memory | 0.5 GB |
| Task execution role | csnp-ecs-execution-role |
| Task role | csnp-ecs-task-role |

## Container Definition

| Field | Value |
| ----- | ----- |
| Container name | wallet-api |
| Image URI | `<ACCOUNT-ID>.dkr.ecr.eastus.amazonaws.com/csnp-wallet-api:v1` |
| Container port | 5000 |
| Protocol | TCP |

## Environment Variables

| Key | Value |
| --- | ----- |
| DB_HOST | `<Azure Database for PostgreSQL-ENDPOINT>` |
| DB_PORT | 5432 |
| DB_NAME | wallet |
| DB_USER | postgres |
| DB_PASSWORD | `<your-password>` (dùng Key Vault ở phần nâng cao, xem cuối lab) |
| Azure Blob Storage_BUCKET | csnp-wallet-dev |

## Logging

| Field | Value |
| ----- | ----- |
| Log driver | awslogs |
| Log group | `/ecs/csnp-wallet-api` |
| Region | eastus |
| Stream prefix | ecs |

> **Khác biệt với Lab 1:** Container Apps tự động tạo log group và gửi `stdout`/`stderr` của container lên Azure Monitor — không cần cài Azure Monitor Agent hay config file `.json` thủ công như Azure VM. Đây là một trong những lợi ích lớn nhất của container orchestration.

---

# Step 6 - NSGs cho Container Apps và ALB

## Tạo NSG cho ALB

```text
Name: csnp-alb-sg
```

| Port | Protocol | Source |
| ---- | -------- | ------ |
| 80 | TCP | 0.0.0.0/0 |

## Tạo NSG cho Container Apps Tasks

```text
Name: csnp-ecs-sg
```

| Port | Protocol | Source |
| ---- | -------- | ------ |
| 5000 | TCP | `csnp-alb-sg` (NSG ID, không phải 0.0.0.0/0) |

> Chỉ ALB mới được gọi thẳng vào container port 5000. Traffic public chỉ vào qua ALB port 80.

## Cập nhật Azure Database for PostgreSQL NSG

Vào `csnp-rds-sg` từ Lab 1, thêm inbound rule mới:

| Port | Source |
| ---- | ------ |
| 5432 | `csnp-ecs-sg` (NSG ID của Container Apps Tasks) |

> Giữ nguyên rule cũ cho phép Azure VM NSG từ Lab 1 nếu còn dùng. Container Azure Container Apps có network interface riêng, không dùng chung IP với Azure VM, nên cần rule riêng.

---

# Step 7 - Tạo Target Group

Azure VM → Target Groups → Create target group

| Field | Value |
| ----- | ----- |
| Target type | IP addresses (bắt buộc cho Container Apps, không phải Instance) |
| Target group name | csnp-wallet-tg |
| Protocol | HTTP |
| Port | 5000 |
| Health check path | `/health` |
| Health check interval | 30 giây |

> **Khác biệt với Azure VM:** Target type phải là "IP addresses" vì Container Apps task không phải là Azure VM instance cố định — mỗi task có IP riêng và có thể thay đổi khi restart.

> **Tạo trước ALB:** Target Group cần được tạo trước ALB vì khi tạo ALB bạn sẽ cần chỉ định target group cho listener.

Click **Create target group** — không cần add targets ngay bây giờ, Container Apps Service sẽ tự động đăng ký task IPs.

---

# Step 8 - Tạo Application Load Balancer

Azure VM → Load Balancers → Create Load Balancer → Application Load Balancer

| Field | Value |
| ----- | ----- |
| Name | csnp-wallet-alb |
| Scheme | Internet-facing |
| VNet | Cùng VNet với Azure Database for PostgreSQL/Container Apps |
| Subnets | Chọn ít nhất 2 public subnet ở 2 AZ khác nhau |
| Security group | csnp-alb-sg |

## Listener

```text
Protocol: HTTP
Port: 80
Forward to: Target Group csnp-wallet-tg (đã tạo ở Step 7)
```

---

# Step 9 - Tạo Container Apps Service

Container Apps → Clusters → csnp-wallet-cluster → Create Service

| Field | Value |
| ----- | ----- |
| Launch type | Container Apps |
| Task definition | csnp-wallet-api (revision mới nhất) |
| Service name | csnp-wallet-service |
| Desired tasks | 2 |
| Subnets | Cùng subnet với Azure Database for PostgreSQL (private hoặc public tùy setup) |
| Security group | csnp-ecs-sg |
| Public IP | Enabled (nếu dùng public subnet) hoặc Disabled (nếu có Azure NAT Gateway) |
| Load balancer | Application Load Balancer → csnp-wallet-alb |
| Target group | Target Group đã tạo ở Step 7 |

> **Desired tasks = 2:** Khác với Azure VM chỉ chạy 1 instance ở Lab 1, Container Apps Service mặc định chạy nhiều task song song để có tính sẵn sàng cao (high availability). Nếu 1 task crash, Container Apps tự khởi động lại task mới.

Click **Create**, chờ vài phút cho task chuyển sang `RUNNING` và health check `Healthy`.

---

# Step 10 - Verify Deployment

## Lấy ALB DNS name

```text
Azure VM → Load Balancers → csnp-wallet-alb → DNS name
```

Dạng: `csnp-wallet-alb-xxxxxxxxx.eastus.elb.amazonaws.com`

## Test API qua ALB

```bash
curl http://<ALB-DNS-NAME>/health
# Expected: {"status":"ok","time":"..."}

curl http://<ALB-DNS-NAME>/wallets
# Expected: []

curl -X POST http://<ALB-DNS-NAME>/wallets \
  -H "Content-Type: application/json" \
  -d '{"ownerId":"user-002","balance":500}'
# Expected: 201 Created

curl -X POST http://<ALB-DNS-NAME>/upload
# Expected: {"bucket":"csnp-wallet-dev","key":"uploads/xxx.txt"}
```

> Không cần chỉ định port 5000 ở đây — ALB lắng nghe port 80 và forward nội bộ sang container port 5000.

## Verify Task Role hoạt động (không dùng Access Key)

```text
Container Apps → Tasks → chọn 1 task đang RUNNING → Logs tab
```

Tìm log không có lỗi `AccessDenied` khi gọi `/upload` — nghĩa là Task Role hoạt động đúng, giống cách verify Microsoft Entra ID / Azure RBAC Instance Role ở Lab 1.

## Test High Availability

```text
Container Apps → Tasks → chọn 1 task → Stop
```

Sau vài giây, Container Apps Service tự khởi động task mới để duy trì Desired count = 2. Đây là điều Azure VM ở Lab 1 không tự làm được — nếu Azure VM crash, app sẽ down cho đến khi can thiệp thủ công.

---

# Step 11 - Verify Azure Monitor Logs

```text
Azure Monitor → Log groups → /ecs/csnp-wallet-api → chọn log stream
```

Thấy log của cả 2 task, mỗi task có 1 stream riêng dạng `ecs/wallet-api/<task-id>`.

So sánh với Lab 1: không cần cài Agent, không cần config file, Container Apps tự động đẩy log lên Azure Monitor ngay khi container start.

---

# Cleanup sau Lab

Xóa theo đúng thứ tự để tránh tốn tiền, đặc biệt là ALB:

```text
1. Container Apps → Service → Update desired count = 0 → Delete service
2. Container Apps → Cluster → Delete cluster
3. Azure VM → Load Balancers → Delete csnp-wallet-alb (QUAN TRỌNG NHẤT — tốn tiền theo giờ)
4. Azure VM → Target Groups → Delete target group
5. ACR → Repository → Delete csnp-wallet-api (hoặc giữ lại nếu cần cho Lab 3)
6. Microsoft Entra ID / Azure RBAC → Roles → Giữ lại csnp-ecs-execution-role, csnp-ecs-task-role cho lab sau
7. Azure Database for PostgreSQL, Azure Blob Storage → Giữ nguyên từ Lab 1 nếu vẫn cần
```

---

# Validation Checklist

## Docker

* [ ] Image build thành công local
* [ ] Container chạy được local, `/health` trả 200

## ACR

* [ ] Image đã push lên ACR thành công
* [ ] Image scan không có lỗ hổng Critical

## Microsoft Entra ID / Azure RBAC

* [ ] Task Execution Role tách biệt với Task Role
* [ ] Container gọi Azure Blob Storage không cần Access Key (verify qua log không có AccessDenied)

## Container Apps

* [ ] Cluster Container Apps tạo thành công
* [ ] Service chạy đúng Desired count = 2
* [ ] Task health check Healthy trên Target Group

## ALB

* [ ] DNS name resolve và curl `/health` trả 200
* [ ] Stop 1 task, Container Apps tự khởi động task thay thế

## Azure Monitor

* [ ] Log group `/ecs/csnp-wallet-api` có log tự động, không cần Agent

---

# Lessons Learned

| Concept | Azure VM (Lab 1) | Azure Container Apps (Lab 2) |
| ------- | ----------- | -------------------- |
| Compute | 1 VM cố định | Nhiều task serverless |
| Microsoft Entra ID / Azure RBAC | 1 Instance Role | 2 role: Execution Role + Task Role |
| Scaling | Thủ công, phải launch thêm Azure VM | Desired count + Auto Scaling policy |
| High Availability | Không có — 1 điểm lỗi duy nhất | Service tự thay task chết |
| Logs | Cần cài Azure Monitor Agent + config | Tự động qua `awslogs` driver |
| Load balancing | Không có, gọi thẳng Azure VM IP | ALB phân phối traffic đến nhiều task |
| Deploy version mới | Azure Policy lại binary, restart thủ công | Push image mới, update service (rolling update) |

**Key takeaways:**

* Azure Container Apps tách Microsoft Entra ID / Azure RBAC thành 2 role rõ ràng: hạ tầng (Execution Role) và ứng dụng (Task Role) — tương tự nguyên tắc Least Privilege nhưng chi tiết hơn Azure VM
* Container hóa giúp logging tự động, không cần Agent thủ công
* ALB + Target Group dùng IP target type cho Container Apps, khác hẳn Azure VM Instance target type
* Self-healing (auto-restart task chết) là lợi ích lớn nhất so với Azure VM đơn lẻ ở Lab 1
* So với self-hosted K8s trên Proxmox: Container Apps Service tương đương K8s Deployment, ALB tương đương Ingress Controller, Task Definition tương đương Pod spec — nhưng Azure quản lý control plane hộ mình

---

# Hướng nâng cao (tùy chọn, không bắt buộc cho lab này)

* **Key Vault:** Thay `DB_PASSWORD` ở dạng plain text trong Task Definition bằng Key Vault reference — tránh lộ password trong console/logs
* **Auto Scaling:** Cấu hình Target Tracking Scaling Policy theo CPU utilization, tự tăng/giảm Desired count
* **HTTPS:** Thêm Azure managed certificates certificate và listener HTTPS 443 trên ALB
* **Service Discovery:** Dùng Azure Cloud Map nếu có nhiều service cần gọi nhau (tương đương K8s DNS service discovery)

---

# Next Lab

Sau khi hoàn thành Lab #2:

```text
AKS Cluster setup
↓
Deploy WalletMinimal lên AKS (so sánh trực tiếp với Azure Container Apps)
↓
Ingress Controller (ALB Ingress hoặc Nginx Ingress)
↓
HPA (Horizontal Pod Autoscaler)
↓
So sánh chi phí và độ phức tạp vận hành: Azure Container Apps vs AKS vs self-hosted K8s (Proxmox)
```

**Mục tiêu Lab 3:** Áp dụng kinh nghiệm K8s sẵn có vào AKS, và đưa ra đánh giá thực tế — khi nào nên chọn Azure Container Apps, khi nào nên chọn AKS, dựa trên trải nghiệm trực tiếp thay vì lý thuyết.

