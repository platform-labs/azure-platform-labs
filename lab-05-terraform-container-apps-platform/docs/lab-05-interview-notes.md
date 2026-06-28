# Azure Lab #5 - Key Concepts & Interview Notes

## 1. Task Execution Role khác Task Role như thế nào?

Task Execution Role là quyền của **hạ tầng Container Apps** — dùng để pull image từ ACR và ghi log lên Azure Monitor. Role này được Container Apps Agent dùng, không liên quan tới logic nghiệp vụ của application.

Task Role là quyền của **chính application** đang chạy trong container — ví dụ gọi Azure Blob Storage, SQS, Azure Blob lease locking. Nếu app cần gọi Azure service nào, quyền đó phải nằm ở Task Role, không phải Task Execution Role.

Lab 2 (Terraform ban đầu) chỉ có Task Execution Role, thiếu hẳn Task Role — nghĩa là nếu app cố gọi Azure Blob Storage từ trong container, request sẽ bị từ chối vì không có credential nào cấp quyền đó. Lab 5 sửa đúng gap này.

### Keywords

* Task Execution Role
* Task Role
* Container Apps Agent vs Application Permissions
* Principle of Least Privilege

---

## 2. Tại sao Container Apps Service đặt trong Private App Subnet, không Public Subnet?

Traffic vào Container Apps task chỉ nên đi qua ALB — ALB đã nằm Public Subnet, nhận traffic từ internet, rồi forward vào Private App Subnet qua NSG Reference (`ecs_sg` chỉ nhận từ `alb_sg`). Container Apps task không cần và không nên có Public IP, vì không có lý do gì internet cần kết nối trực tiếp tới task — mọi traffic hợp lệ đều đi qua ALB.

Đặt Container Apps task ở Private Subnet thu nhỏ surface area: nếu task có lỗ hổng, attacker không thể kết nối trực tiếp tới nó từ internet, chỉ có thể đi qua ALB (nơi có thể áp thêm WAF, rate limiting sau này).

### Keywords

* Private Subnet
* Attack Surface Reduction
* ALB as single entry point
* assign_public_ip = false

---

## 3. `network_mode = "awsvpc"` nghĩa là gì, tại sao Container Apps bắt buộc?

Với `awsvpc` mode, mỗi Task có ENI (Elastic Network Interface) riêng, IP riêng trong VNet — khác với `bridge` mode (Docker network truyền thống, các container share IP của host). Container Apps không quản lý Azure VM host nên buộc dùng `awsvpc` để mỗi task có network identity độc lập, từ đó NSG có thể áp trực tiếp lên Task (`network_configuration.security_groups` trong `azure_ecs_service`) thay vì áp lên Azure VM host.

Đây cũng là lý do `target_type = "ip"` bắt buộc cho Target Group khi dùng Container Apps — ALB route theo IP của Task, không phải Instance ID, vì task không gắn cố định vào Azure VM instance nào.

### Keywords

* awsvpc network mode
* ENI per Task
* target_type = ip
* Container Apps vs Azure VM launch type

---

## 4. Tại sao Lab 5 không tự tạo VNet/Subnet, mà nhận qua variable?

Network là layer riêng, đã được Lab 3 (hiểu bằng tay) và Lab 4 (Terraform hoá) xây xong. Lab 5 chỉ quan tâm tới compute layer (Container Apps) — nhận `vpc_id`, `*_subnet_ids`, NSG ID làm input qua `variables.tf`, không re-declare hoặc tạo lại.

Cách tổ chức này phản ánh đúng ranh giới trách nhiệm trong một platform thật: network team (hoặc network module) sở hữu VNet, application/platform team chỉ tiêu thụ output của network layer. Tách rõ ranh giới này ngay từ lab giúp sau này refactor thành Terraform module thật không cần đổi mindset, chỉ đổi cách truyền input (variable → module output, hoặc remote state).

### Keywords

* Separation of Concerns
* Network as Input, not Resource
* Terraform Module Boundary
* Remote State (for later)

---

## 5. Vì sao NSG của Container Apps được tái sử dụng từ Lab 4, không tạo SG mới ở Lab 5?

NSG là tài sản của network layer (ai được nói chuyện với ai), không phải tài sản của compute layer. Lab 4 đã định nghĩa đúng quan hệ `ecs_sg` chỉ nhận từ `alb_sg` — Lab 5 chỉ cần tham chiếu ID đó (`var.ecs_security_group_id`) khi tạo `azure_ecs_service`, không tạo SG trùng lặp.

Nếu mỗi lab tự tạo SG riêng cho cùng một resource logic, sẽ dẫn tới tình trạng nhiều SG chồng chéo, khó audit ai đang mở port nào cho ai — một anti-pattern thường gặp khi hệ thống lớn dần mà không có quy ước rõ network resource thuộc layer nào.

### Keywords

* NSG Ownership
* Avoiding Duplicate Resources
* Infrastructure Layering
* Auditability

---

## 6. Tại sao Lab 5 (không phải Lab 4) sở hữu Azure Database for PostgreSQL Flexible Server?

**Roadmap evolution:**
- Lúc đầu: Azure Database for PostgreSQL từng nằm trong scope Lab 4 (cùng với VNet + Networking)
- **Hiện tại (refactored):** Lab 4 = **Network Layer ONLY** (VNet, Subnet, NSG). Lab 5 = **Application Stack Layer** (Container Apps, Azure Database for PostgreSQL, Azure Blob Storage)

**Lý do tách biệt:**

Network infrastructure (VNet, Subnet, SG, Route Table) là foundation layer, được tái sử dụng bởi nhiều application stacks. Azure Database for PostgreSQL Flexible Server là tài sản của *một application cụ thể* (Wallet API), không phải tài sản chung của infrastructure.

Trong một hệ thống production:
- Network team provision VNet + Subnet + SG (share across multiple apps)
- Application team sở hữu và quản lý database của app riêng mình

Lab 5 phản ánh đúng pattern này:
- Azure Database for PostgreSQL DB Subnet Group: sử dụng subnets từ Lab 4 (input, không tạo lại)
- Azure Database for PostgreSQL NSG: từ Lab 4 (input, không tạo lại) — nhưng Lab 5 đặt Azure Database for PostgreSQL resource
- Azure Database for PostgreSQL Credentials & Lifecycle: hoàn toàn sở hữu bởi Lab 5

Nếu delete Lab 5, Azure Database for PostgreSQL instance cũng bị xóa theo (managed bởi Terraform của Lab 5), không ảnh hưởng tới Lab 4 network. Điều này là **clean separation of concerns**.

### Keywords

* Database Ownership
* Application Stack Isolation
* Separation of Concerns (Database Layer)
* Production Database Patterns

---

## 7. Tại sao Lab 5 tạo Azure Blob Storage bucket mới, không dùng bucket từ Lab 1?

Lab 1 tạo Azure Blob Storage bucket để thực hành Azure Blob Storage API từ Azure VM instance (với instance role). Bucket đó là "shared infrastructure" mục đích learning.

Lab 5 tạo Azure Blob Storage bucket riêng cho Container Apps Platform stack, do Terraform manage. Bucket này được gắn với Task Role của Container Apps tasks, cho phép app bên trong container upload/download files. Bucket mới này:
- Tên bucket include `account-id` + `region` (tránh trùng tên với bucket global khác)
- Bật versioning và encryption (best practice)
- Gắn với Task Role (Container Apps tasks có quyền PUT/GET/LIST)
- Cleanup tự động khi `terraform destroy`

Lý do tách biệt: Lab 1 là thực hành Azure VM + Azure Blob Storage API trực tiếp (imperative), Lab 5 là platform stack hoàn chỉnh (declarative Terraform). Mỗi lab có bucket riêng giúp minh họa rõ ràng: 
- How to use Azure Blob Storage (Lab 1)
- How to provision & integrate Azure Blob Storage into a full application stack (Lab 5)

Nếu dùng chung bucket Lab 1, sẽ khó hiểu ranh giới ownership, khó test cleanup, và bucket vẫn tồn tại sau khi destroy Lab 5.

### Keywords

* Azure Blob Storage Bucket Ownership per Stack
* IaC Declarative Management
* Bucket Naming Strategy (account-id, region)
* Versioning & Encryption Best Practices

---

# Tóm tắt phỏng vấn trong 60 giây

"Tôi Terraform hoá toàn bộ Container Apps Platform stack bao gồm compute (Container Apps Service, Task Definition), networking (tham chiếu VNet/Subnet/SG từ Lab 4), và data layer (Azure Database for PostgreSQL Flexible Server, Azure Blob Storage bucket). Container Apps Service đặt ở Private App Subnet, chỉ nhận traffic qua ALB từ Public Subnet, tách biệt Task Execution Role (hạ tầng) và Task Role (app permissions). Azure Database for PostgreSQL instance được đặt trong Private Data Subnets thông qua DB Subnet Group, bật encryption và automated backups. Azure Blob Storage bucket được provision với versioning và public access blocked. Network (VNet/Subnet/SG) không được tạo lại — chỉ tham chiếu từ Lab 4 — vì network là infrastructure layer tách biệt, compute layer chỉ tiêu thụ. Cách tổ chức này phản ánh production pattern: mỗi application stack sở hữu database và object storage của riêng nó, giữ nguyên ranh giới layer để dễ scale, rebuild, hay refactor thành module sau này."

