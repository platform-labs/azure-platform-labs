# Lab 05 - Terraform Container Apps Platform

## Mục tiêu

Terraform-hoá đúng kiến trúc Container Apps + ALB + Azure Database for PostgreSQL + Azure Blob Storage của Lab 2, nhưng lần này đặt **đúng vào Custom VNet 3-tier** đã xây ở Lab 3A/Lab 4 — không còn `assign_public_ip = true`, không còn default VNet. Đây cũng là lab đầu tiên **tách rõ Task Execution Role và Task Role** thành 2 Managed Identity riêng biệt.

**Azure Database for PostgreSQL + Azure Blob Storage được tạo bởi Lab 5**, không phải Lab 4. Lab 4 chỉ cung cấp network layer (VNet, Subnet, NSG); Lab 5 tạo toàn bộ app stack (Azure Database for PostgreSQL, Azure Blob Storage, Container Apps, ALB, Managed Identity).

Sau lab này cần hiểu được:

* Container Apps Service đặt trong Private App Subnet, không có Public IP — traffic vào chỉ qua ALB
* Task Execution Role (hạ tầng Container Apps: pull image, ghi log) khác Task Role (quyền của application: gọi Azure Blob Storage, Azure Database for PostgreSQL)
* ALB nằm Public Subnet, target type `ip` cho Container Apps (giữ nguyên từ Lab 2)
* Azure Database for PostgreSQL Flexible Server đặt trong Private Data Subnet, accessible qua app stack chỉ qua NSG inbound rule
* Azure Blob Storage bucket được tạo với encryption, versioning, public access blocked (best practice)
* Terraform inputs từ Lab 4 (VNet ID, Subnet IDs, NSG IDs), không tạo network resources

## ⚠️ Prerequisite — BẮT BUỘC đọc trước khi chạy

* **Lab 3A + 3B đã hoàn thành** (Console + CLI, hiểu rõ VNet/Subnet/Route Table/NAT)
* **Lab 4 đã `terraform apply` thành công** — Lab 5 tiêu thụ output của Lab 4 (VNet ID, Subnet IDs, NSG IDs)

Required outputs từ Lab 4 (chạy `terraform output` trong `lab-04-terraform-platform-foundation/terraform/`):

```
vpc_id
public_subnet_ids
private_app_subnet_ids
private_data_subnet_ids
alb_security_group_id
ecs_security_group_id
rds_security_group_id
```

Copy các giá trị này vào `terraform.tfvars` của Lab 5 (xem `terraform.tfvars.example`). Lab 4 và Lab 5 đều lưu state trên Azure Blob Storage với key độc lập, nhưng Lab 5 vẫn copy output thủ công để dependency dễ quan sát khi học. Có thể đổi sang `data "terraform_remote_state"` sau khi đã hiểu trade-off coupling và state access.

> **Note:** Lab 5 tự tạo Azure Database for PostgreSQL instance + Azure Blob Storage bucket — không cần từ ngoài. Chỉ cần network layer từ Lab 4.

## Architecture

```text
                              Internet
                                  |
                                  v
                 +----------------------------------+
                 |          Public Subnet            |    <- từ Lab 4
                 |   ALB (csnp-platform-alb)          |
                 +----------------------------------+
                                  |
                    (Target Group, target_type=ip)
                                  v
                 +----------------------------------+
                 |       Private App Subnet          |    <- từ Lab 4
                 |   Azure Container Apps Service              |
                 |   desired_count = 2 (2 AZ)         |
                 |   assign_public_ip = false         |
                 +----------------------------------+
                                  |
                          (DB_HOST env var)
                                  v
                 +----------------------------------+
                 |       Private Data Subnet         |    <- Azure Database for PostgreSQL (cần làm ở phần mở rộng Lab 4)
                 +----------------------------------+
```

## So sánh với Lab 2

| | Lab 2 | Lab 5 |
| --- | --- | --- |
| VNet | Default VNet | Custom VNet (từ Lab 4) |
| Container Apps Subnet | Default Subnet, public | Private App Subnet |
| `assign_public_ip` | `true` | `false` |
| Managed Identity | Chỉ Task Execution Role | Task Execution Role + Task Role riêng |
| Task Role Azure Blob Storage access | (chưa có, app không gọi được Azure Blob Storage từ Container Apps) | Có, scoped đúng 1 bucket + 2 action |
| `DB_PASSWORD` | Thiếu hẳn trong Task Definition | Có, nhưng plain env var — known gap, xem dưới |

## Azure Services

| Service | Vai trò |
| ------- | ------- |
| ACR | `csnp-platform-wallet-api`, scan on push |
| Container Apps Cluster + Service + Task Definition | Container Apps, 2 task, Private App Subnet |
| ALB + Target Group + Listener | Public Subnet, port 80, health check `/health` |
| **Azure Database for PostgreSQL Flexible Server** | **Private Data Subnet, accessible qua Container Apps NSG** |
| **Azure Blob Storage Bucket** | **Encrypted, versioning enabled, public access blocked** |
| Managed Identity | Task Execution Role (Container Apps infra) + Task Role (app permissions) riêng biệt |
| Azure Monitor Log Group | `/ecs/csnp-platform-wallet-api`, retention 14 ngày |

## Known Gaps (cố ý, không phải thiếu sót) + tạo Azure Database for PostgreSQL + Azure Blob Storage" của lab này.
* **Không có HTTPS/Azure managed certificates listener** — chỉ HTTP port 80. TLS termination là concern riêng (cert, Azure DNS), ngoài scope.
* **Container Insights disabled** — bật ở Lab 6 (Observability).
* **Azure Database for PostgreSQL: No automated backup to Azure Blob Storage, no encryption key alias** — backup rotation là Lab 6/7 (DR topic), encryption key alias cleanup là operational task, không phải IaC scope của lab nàyecrets Manager. Đây là quyết định đã thống nhất từ trước — Key Vault (kèm Key Vault keys, rotation) để dành Lab 6/7, tránh loãng trọng tâm "đặt Container Apps đúng vào Custom VNet" của lab này.
* **Không có HTTPS/Azure managed certificates listener** — chỉ HTTP port 80. TLS termination là concern riêng (cert, Azure DNS), ngoài scope.
* **Container Insights disabled** — bật ở Lab 6 (Observability).
* **1 Azure NAT Gateway** (kế thừa từ Lab 4) — nếu AZ chứa NAT down, Container Apps task ở AZ còn lại vẫn chạy được (không cần internet để serve traffic qua ALB), nhưng sẽ không pull được image mới nếu cần restart task lúc đó.

## Estimated Cost

| Resource | Chi phí ước tính |
| -------- | ----------------- |
| ALB | ~$16/tháng + LCU |
| Container Apps (2 task, 0.25 vCPU/0.5GB) | ~$18-20/tháng nếu chạy 24/7 |
| ACR | Free tier 500MB, sau đó theo dung lượng |
| Azure Monitor Logs | Free tier 5GB, sau đó theo dung lượng |

## Region

`eastus`

## Cleanup

```bash
terraform destroy
```

Không ảnh hưởng tới VNet của Lab 4 — Lab 5 chỉ tạo ACR/Container Apps/ALB/Managed Identity, không tạo network resource nào.

## Lessons Learned

* Tách Task Execution Role và Task Role ngay từ đầu giúp tránh việc Task Role "mượn" quyền của Execution Role hoặc ngược lại — một lỗi cấu hình Container Apps rất phổ biến khi mới học.
* Network là input, không phải resource của lab này — cách tổ chức này (Terraform module/lab chỉ tạo đúng layer của mình, nhận layer dưới qua variable) là chuẩn bị tự nhiên cho việc tách module thật sau này.
* `assign_public_ip = false` không tự động hoạt động nếu NSG hoặc Route Table của Private App Subnet sai — đây là lý do Lab 3/Lab 4 phải làm đúng trước, không thể bỏ qua.
* Chi tiết Q&A phỏng vấn xem [`docs/lab-05-interview-notes.md`](./docs/lab-05-interview-notes.md). Hands-on checklist xem [`docs/lab-05-hands-on.md`](./docs/lab-05-hands-on.md).
Bây giờ đã Complete (không phải skeleton nữa).** Azure Database for PostgreSQL + Azure Blob Storage đã thêm vào, variables đã update, ecs.tf đã dùng data source từ rds.tf + s3.tf. Sẵn sàng apply sau khi hoàn thành Lab 4 và copy `terraform.tfvars`
## Trạng thái

**Skeleton — chưa apply.** Viết sau khi hoàn thành thiết kế Lab 3/Lab 4 (theo roadmap), chờ anh thực hành Lab 3/Lab 4 thật trước khi quay lại điền `terraform.tfvars` và apply lab này.

