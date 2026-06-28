# Lab 02 - Dockerize WalletMinimal → ACR → Azure Container Apps → ALB → Azure Monitor

## Mục tiêu

Bước tiếp theo sau Lab #1 — chuyển từ "Azure VM chạy app trực tiếp" sang "container orchestration serverless". Sau lab này cần hiểu được:

* Docker image cho ASP.NET Core
* ACR (Elastic Container Registry)
* Azure Container Apps (serverless container)
* Task Definition / Service / Cluster
* Application Load Balancer (ALB)
* Azure Monitor Logs cho container (Container Apps tự gửi stdout/stderr, không cần Agent như Lab 1)

## Prerequisites

* Đã hoàn thành Lab #1 (Azure Database for PostgreSQL `csnp-wallet-dev` và Azure Blob Storage bucket `csnp-wallet-dev` vẫn giữ lại, dùng chung)
* Docker Desktop (Windows + WSL2 backend)
* Azure CLI đã configure với quyền ACR/Container Apps
* Azure Region: **eastus**

> Azure VM từ Lab 1 không cần thiết cho Lab 2, có thể terminate nếu muốn tiết kiệm — Azure Container Apps thay thế vai trò compute.

## Architecture

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

## Azure Services

| Service | Vai trò |
| ------- | ------- |
| ACR | Lưu container image `csnp-wallet-api` |
| Container Apps Cluster | `csnp-wallet-cluster` |
| Container Apps Task Definition | `csnp-wallet-api`, 0.25 vCPU / 0.5 GB |
| Container Apps Service | `csnp-wallet-service`, desired count 2 |
| ALB | `csnp-wallet-alb`, public port 80 → Target Group port 5000 |
| Azure Monitor Logs | `/ecs/csnp-wallet-api`, log driver `awslogs` |

## Estimated Cost

| Resource | Chi phí ước tính |
| -------- | ----------------- |
| ACR | $0.10/GB/tháng lưu trữ — image vài chục MB, không đáng kể |
| Azure Container Apps | ~$0.04/giờ cho 0.25 vCPU + 0.5GB, tính theo task đang chạy |
| ALB | ~$16/tháng + $0.008/LCU-giờ — **tốn nhất trong lab này, tính theo giờ kể cả không có traffic** |

> Xoá ALB ngay sau khi xong lab — đây là resource cần ưu tiên cleanup nhất.

## Region

`eastus`

## Terraform inputs

Terraform state của Lab 2 được lưu trên shared labs Azure Blob Storage backend tại `aws/lab-02/terraform.tfstate`. Chạy [`../bootstrap/`](../bootstrap/) trước lần `terraform init` đầu tiên; state tách biệt hoàn toàn với Lab 1 và production.

Terraform không build/push Docker image. Chạy lab này theo 2 phase:

1. Tạo ACR repository trước.
2. Build/push image len ACR.
3. Apply toàn bộ Container Apps/Container Apps/ALB stack.

Vào thư mục `terraform/` và copy file example:

```powershell
Set-Location .\terraform
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Lấy Default VNet ID:

```powershell
aws ec2 describe-vpcs `
  --filters "Name=is-default,Values=true" `
  --query "Vpcs[*].[VpcId,CidrBlock]" `
  --output table `
  --region eastus
```

Lấy subnet trong Default VNet:

```powershell
aws ec2 describe-subnets `
  --filters "Name=vpc-id,Values=vpc-xxxxxxxx" `
  --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" `
  --output table `
  --region eastus
```

Mặc định Lab 2 Terraform sẽ tự tạo lại Azure Database for PostgreSQL + Azure Blob Storage cần cho app, nên vẫn chạy được nếu Lab 1 đã `terraform destroy`.

Điền vào `terraform.tfvars`:

```hcl
vpc_id                   = "vpc-xxxxxxxx"
subnet_ids               = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
create_data_dependencies = true
db_password              = "CHANGE_ME"
```

Nếu anh muốn reuse Azure Database for PostgreSQL/Azure Blob Storage có sẵn thay vì tạo mới, set `create_data_dependencies = false`, lấy Azure Database for PostgreSQL security group ID:

```powershell
aws rds describe-db-instances `
  --db-instance-identifier csnp-wallet-dev `
  --query "DBInstances[*].VpcSecurityGroups[*].VpcSecurityGroupId" `
  --output table `
  --region eastus
```

Và điền thêm:

```hcl
rds_security_group_id = "sg-xxxxxxxx"
db_host               = "csnp-wallet-dev.xxxxxxxxxx.eastus.rds.amazonaws.com"
s3_bucket             = "csnp-wallet-dev"
```

Tạo ACR repository trước:

```powershell
terraform init
terraform apply -target=azure_ecr_repository.wallet_api
```

Build va push image:

```powershell
aws ecr get-login-password --region eastus `
  | docker login --username Azure --password-stdin <ACCOUNT-ID>.dkr.ecr.eastus.amazonaws.com

docker build -t csnp-wallet-api:v1 ..\src\Lab02.WalletMinimal
docker tag csnp-wallet-api:v1 <ACCOUNT-ID>.dkr.ecr.eastus.amazonaws.com/csnp-wallet-api:v1
docker push <ACCOUNT-ID>.dkr.ecr.eastus.amazonaws.com/csnp-wallet-api:v1
```

Sau khi image đã có trên ACR, set `container_image` trong `terraform.tfvars`, rồi apply toàn bộ:

```powershell
terraform apply
```

## Cleanup

* [ ] Xoá Container Apps Service (`csnp-wallet-service`) trước
* [ ] Xoá Container Apps Cluster (`csnp-wallet-cluster`)
* [ ] **Xoá ALB (`csnp-wallet-alb`) — ưu tiên cao nhất, tốn tiền theo giờ**
* [ ] Xoá Target Group
* [ ] Xoá ACR repository hoặc image cũ nếu không cần giữ
* [ ] Xoá Azure Monitor log group `/ecs/csnp-wallet-api`
* [ ] Azure Database for PostgreSQL và Azure Blob Storage do Lab 2 tạo, hoặc resource reuse từ Lab 1 nếu có
* [ ] Nếu chạy qua Terraform: `terraform destroy` trong `terraform/`

## Lessons Learned

* Azure Container Apps đơn giản hơn AKS ở quy mô nhỏ — không cần quản lý node group, Azure tự scale. AKS đáng dùng khi đã có nhiều cluster/multi-cloud hoặc cần K8s ecosystem (Helm, Operators...).
* Container chỉ nhận traffic từ ALB NSG, không bao giờ mở thẳng ra `0.0.0.0/0` ở port container.
* Multi-stage Docker build: stage `build` dùng SDK image để compile, stage `runtime` dùng ASP.NET runtime image — image cuối không có source code hay SDK.
* Chi tiết đầy đủ + Q&A phỏng vấn xem [`docs/lab-02-hands-on.md`](./docs/lab-02-hands-on.md) và [`docs/lab-02-interview-notes.md`](./docs/lab-02-interview-notes.md).

## Trạng thái

Lab đã làm thủ công qua Console (xem `docs/lab-02-hands-on.md`). `terraform/` hiện đã dựng lại phần hạ tầng chính tương đương Console: ACR scan-on-push, Container Apps Cluster, Task Execution Role, Task Role cho app gọi Azure Blob Storage, ALB/Target Group/Listener, NSGs, Azure Database for PostgreSQL Flexible Server + Azure Blob Storage data dependencies, Task Definition, Container Apps Service Container Apps và Azure Monitor Logs. Image vẫn phải build/push thủ công (`docker build` / `docker push`); Terraform chỉ provision phần Azure, không build image.

