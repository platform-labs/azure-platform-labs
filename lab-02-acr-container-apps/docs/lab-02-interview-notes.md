# Azure Lab #2 - Key Concepts & Interview Notes

## 1. Tại sao Dockerfile cần Multi-stage Build?

Stage `build` dùng SDK image (nặng, có compiler) chỉ để compile và publish code.

Stage `runtime` dùng ASP.NET runtime image (nhẹ hơn nhiều) để chạy.

Image cuối cùng chỉ copy phần `publish` từ stage build sang, không có source code hay SDK — nhỏ gọn hơn và giảm bề mặt tấn công (ít tool, ít thư viện không cần thiết trong image production).

### Keywords

* Multi-stage Build
* Build Stage vs Runtime Stage
* Image Size
* Attack Surface

---

## 2. Azure Container Apps khác Azure VM (Lab 1) như thế nào?

Azure VM là compute cố định — phải tự chọn instance, tự quản lý OS, tự cài Agent.

Azure Container Apps là serverless container compute — không cần quản lý node/instance, chỉ cần định nghĩa Task Definition (CPU/Memory/Image), Azure tự cấp phát compute cho từng task.

### Keywords

* Serverless Compute
* Task Definition
* Self-managed vs Azure-managed
* Container Orchestration

---

## 3. Tại sao Container Apps cần 2 Managed Identity thay vì 1 như Azure VM?

Azure VM chỉ có 1 Instance Role duy nhất, dùng chung cho cả hạ tầng và ứng dụng.

Azure Container Apps tách rõ 2 vai trò:

* **Task Execution Role** — quyền của hạ tầng Container Apps, để pull image từ ACR và ghi log lên Azure Monitor.
* **Task Role** — quyền của chính ứng dụng đang chạy bên trong container, ví dụ gọi Azure Blob Storage.

Tách riêng giúp áp dụng Least Privilege chi tiết hơn: hạ tầng khởi động container không cần quyền gọi Azure Blob Storage, và ứng dụng không cần quyền pull image.

### Keywords

* Task Execution Role
* Task Role
* Least Privilege
* Separation of Duties

---

## 4. Tại sao Target Group phải dùng Target Type "IP addresses" thay vì "Instance"?

Container Apps task không phải là Azure VM instance cố định — mỗi task có network interface và IP riêng, có thể thay đổi khi task bị restart hoặc thay thế.

Target Type "Instance" giả định target là một Azure VM instance ổn định, không phù hợp với Container Apps. Target Type "IP addresses" cho phép ALB route trực tiếp đến IP hiện tại của từng task.

### Keywords

* Target Type
* IP Target
* awsvpc Network Mode
* Ephemeral IP

---

## 5. Tại sao NSG của Container Apps Tasks chỉ cho phép từ ALB NSG?

Container chỉ nên nhận traffic đã đi qua ALB, không nên expose thẳng container port ra Internet.

Bằng cách reference NSG của ALB (`csnp-alb-sg`) thay vì `0.0.0.0/0`, chỉ traffic đã qua ALB mới chạm được container port 5000 — traffic public chỉ vào được qua ALB port 80.

### Keywords

* NSG Reference
* Defense in Depth
* Network Isolation
* Application Tier

---

# Tóm tắt phỏng vấn trong 30 giây

"Tôi container hóa Wallet API bằng Docker multi-stage build để image gọn và an toàn hơn, sau đó push lên ACR và deploy qua Azure Container Apps — serverless, không cần tự quản lý node. Container Apps tách Microsoft Entra ID / Azure RBAC thành Task Execution Role cho hạ tầng và Task Role cho ứng dụng, áp dụng Least Privilege chi tiết hơn Azure VM. Traffic vào qua Application Load Balancer với Target Type IP addresses vì Container Apps task không có IP cố định, và NSG của container chỉ chấp nhận traffic từ ALB, không mở thẳng ra Internet."

---

## 6. Azure Monitor Logs ở Container Apps khác Azure VM (Lab 1) như thế nào?

Ở Lab 1, phải tự cài Azure Monitor Agent và config file để đọc `/var/log/app/application.log` rồi gửi lên Azure Monitor.

Ở Container Apps, chỉ cần khai báo log driver `awslogs` trong Task Definition. Container Apps tự động gửi `stdout`/`stderr` của container lên Azure Monitor ngay khi container start, không cần Agent hay config thủ công.

### Keywords

* awslogs Driver
* Centralized Logging
* No Agent Required
* Container Logging

---

## 7. Tại sao Desired Count = 2 quan trọng?

Lab 1 chỉ chạy 1 Azure VM instance — một điểm lỗi duy nhất (single point of failure), nếu instance crash thì app down cho đến khi can thiệp thủ công.

Container Apps Service với Desired Count = 2 chạy song song 2 task. Nếu 1 task crash, Container Apps tự khởi động task mới để duy trì đúng số lượng mong muốn — đây là cơ chế self-healing.

### Keywords

* Desired Count
* High Availability
* Self-healing
* Single Point of Failure

---

## 8. Application Load Balancer hoạt động ở Layer nào?

ALB hoạt động ở Layer 7 (Application Layer) — hiểu được HTTP, có thể route theo path, host header, và thực hiện health check ở tầng application (ví dụ gọi `/health`).

Khác với Network Load Balancer (Layer 4), chỉ route theo IP/port mà không hiểu nội dung HTTP.

### Keywords

* Layer 7 Load Balancing
* ALB vs NLB
* Path-based Routing
* Health Check

---

## 9. Tại sao Container chạy port 5000 nhưng ALB nghe port 80?

Giống lý do ở Lab 1 (port nhỏ hơn 1024 là Privileged Port), container vẫn chạy ở port không privileged như 5000.

ALB đứng giữa, lắng nghe public port 80 (hoặc 443 cho HTTPS) và forward nội bộ sang container port 5000 qua Target Group. Client gọi ALB không cần biết container đang chạy port nào.

### Keywords

* Privileged Ports
* Listener
* Target Group Port Mapping
* Reverse Proxy Pattern

---

## 10. Tại sao phải tạo NSG rule mới cho Azure Database for PostgreSQL thay vì dùng lại rule của Azure VM?

Container Apps task chạy ở network mode `awsvpc`, mỗi task có network interface (ENI) riêng, không dùng chung IP hay NSG với Azure VM instance ở Lab 1.

Vì vậy Azure Database for PostgreSQL NSG cần thêm rule mới cho phép NSG của Container Apps Tasks (`csnp-ecs-sg`) truy cập port 5432, bên cạnh rule cũ của Azure VM nếu vẫn còn dùng.

### Keywords

* awsvpc Network Mode
* Elastic Network Interface (ENI)
* NSG Reference
* Multi-source Access Rule

---

## 11. Tại sao cần Access Key tạm thời khi test local, trong khi cả lab đều dùng Managed Identity?

Máy local không có Instance Metadata Service (IMDS) như Azure VM, và không có Task Role như Container Apps, nên không thể lấy Temporary Credentials qua các cơ chế đó.

Đây là **ngoại lệ duy nhất** trong toàn bộ lab — dùng Access Key tạm thời chỉ để test container chạy local trước khi push lên ACR. Khi deploy lên Container Apps, container sẽ dùng Task Role thật, không cần Access Key. Access Key tạm này nên được revoke ngay sau khi test xong.

### Keywords

* Local Testing Exception
* Temporary Access Key
* IMDS Unavailable Locally
* Task Role

---

## 12. Container Apps Task Definition khác Container Apps Service như thế nào?

Task Definition là **blueprint** — định nghĩa image, CPU/Memory, port, environment variables, Microsoft Entra ID / Azure RBAC roles, logging config cho một loại task.

Container Apps Service là **trình quản lý vòng đời** — giữ cho đúng số lượng task (Desired Count) luôn chạy dựa trên Task Definition, gắn với Load Balancer, và tự thay task chết.

Quan hệ tương tự Docker image (blueprint) và container đang chạy (instance), nhưng ở tầng orchestration cao hơn.

### Keywords

* Task Definition
* Container Apps Service
* Blueprint vs Runtime State
* Desired State Management

---

## 13. Khi nào chọn Azure Container Apps, khi nào chọn AKS?

| | Azure Container Apps | AKS |
| - | ----------- | --- |
| Control plane | Azure quản lý, không trả phí riêng | $0.10/giờ cho control plane |
| Quản lý node | Không cần, serverless | Cần quản lý node group hoặc Container Apps profile |
| Learning curve | Thấp, chỉ cần hiểu Task Definition | Cao, cần hiểu kubectl, manifests, RBAC |
| Phù hợp | Team nhỏ, ít service, ship nhanh | Team lớn, nhiều service, cần K8s ecosystem |

Azure Container Apps phù hợp khi muốn đơn giản, rẻ ở quy mô nhỏ-vừa, không cần đội riêng vận hành control plane. AKS đáng dùng khi đã có nhiều cluster/multi-cloud hoặc cần hệ sinh thái K8s (Helm, Operators).

### Keywords

* Container Apps vs AKS
* Control Plane
* Learning Curve
* Workload Fit

---

## 14. Azure Container Apps map sang khái niệm Kubernetes như thế nào?

Với người đã quen self-hosted K8s, có thể map trực tiếp:

* Container Apps Service ≈ Kubernetes Deployment
* Application Load Balancer ≈ Ingress Controller
* Task Definition ≈ Pod Spec
* Desired Count ≈ `replicas` trong Deployment

Khác biệt lớn nhất: Azure quản lý control plane hộ mình ở Azure Container Apps, còn self-hosted K8s phải tự vận hành control plane.

### Keywords

* Container Apps to Kubernetes Mapping
* Deployment
* Ingress Controller
* Pod Spec

---

## 15. Tại sao không nên để DB_PASSWORD ở dạng plain text trong Task Definition?

Environment variable dạng plain text trong Task Definition có thể bị xem trực tiếp qua Azure Console hoặc qua log, ai có quyền đọc Task Definition cũng đọc được password.

Cách tốt hơn là dùng Azure Key Vault reference trong Task Definition — Container Apps sẽ lấy giá trị thật tại runtime mà không lưu plain text trong definition.

### Keywords

* Key Vault
* Plain Text Secret
* Task Definition Security
* Runtime Secret Injection

---

## 16. Self-healing trong Container Apps hoạt động như thế nào khi 1 task bị crash?

Container Apps Service liên tục theo dõi số task đang `RUNNING` so với Desired Count đã khai báo.

Nếu 1 task bị stop hoặc health check fail liên tục, Container Apps sẽ tự dừng task đó và khởi động task mới để duy trì đúng Desired Count — không cần can thiệp thủ công, khác hẳn với việc 1 Azure VM instance chết ở Lab 1.

### Keywords

* Self-healing
* Desired Count Reconciliation
* Health Check Failure
* Service Scheduler

---

# Tóm tắt phỏng vấn trong 60 giây

"Tôi dockerize Wallet API bằng multi-stage build rồi push image lên ACR. Trên Azure Container Apps, tôi tách Microsoft Entra ID / Azure RBAC thành Task Execution Role cho hạ tầng và Task Role cho ứng dụng, thay vì 1 role duy nhất như Azure VM. Service chạy với Desired Count = 2 đứng sau Application Load Balancer, Target Group dùng Target Type IP addresses vì mỗi Container Apps task có IP riêng không cố định. NSG của container chỉ chấp nhận traffic từ ALB, và Azure Database for PostgreSQL có thêm rule riêng cho NSG của Container Apps Tasks vì Container Apps dùng network mode awsvpc, không chung IP với Azure VM. Azure Monitor nhận log tự động qua awslogs driver, không cần cài Agent như Lab 1. Khi 1 task crash, Container Apps Service tự khởi động task mới để duy trì Desired Count — đây là self-healing, khác hẳn với Azure VM đơn lẻ ở Lab 1. So với self-hosted Kubernetes, Container Apps Service tương đương Deployment, ALB tương đương Ingress Controller, Task Definition tương đương Pod Spec, nhưng Azure quản lý control plane hộ mình."

