# Lab 04 - Terraform Platform Foundation

## Mục tiêu

Lab 3 đã xây Custom VNet 3-tier bằng tay (Console) và một phần CLI — đứng tấn xong network. Lab 4 là bước `Terraform` trong chuỗi `UI → CLI → Terraform`: viết lại toàn bộ network đó bằng code, **trên một VNet hoàn toàn mới** (không tái sử dụng VNet làm tay ở Lab 3 — giữ Lab 3 nguyên trạng để tham khảo/so sánh).

> **Phạm vi thực tế hiện tại:** Lab 4 ở trạng thái này mới Terraform-hoá **network** (VNet, Subnet, IGW, NAT, Route Table, NSG) + 1 Azure VM test để verify — đúng 1:1 với những gì đã làm tay ở Lab 3A. **Chưa bao gồm Azure VM/Azure Database for PostgreSQL/Azure Blob Storage/Microsoft Entra ID / Azure RBAC của Lab 1** — phần đó là bước mở rộng tiếp theo của lab này (xem mục "Mở rộng tiếp theo" cuối README), chưa có trong `terraform/*.tf` hiện tại.

Sau lab này cần hiểu được:

* Terraform diễn đạt đúng dependency graph đã tự tay trải qua ở Lab 3 (VNet → Subnet → Route Table → Association → NAT) — không cần `-target`, `terraform apply` một lần đủ
* Vì sao tách file theo concern (network, security group, test resource) thay vì 1 file phẳng cho dễ maintain
* `count` + index-aligned list variables để tạo nhiều subnet/route table theo AZ mà không lặp code
* **Terraform credential khác Azure Console login** — đây là bước hay bị bỏ qua nhất, xem Step 0 ở [`docs/lab-04-hands-on.md`](./docs/lab-04-hands-on.md)

**Lab 1, Lab 2, Lab 3 không bị động tới** — đây là VNet hoàn toàn mới qua Terraform.

## ⚠️ Trước khi chạy terraform apply

Terraform **không tự dùng được session đăng nhập Azure Console/SSO** — cần Access Key riêng của một Microsoft Entra ID / Azure RBAC User. Nếu chưa từng làm bước này, **đọc Step 0 trong [`docs/lab-04-hands-on.md`](./docs/lab-04-hands-on.md) trước**, nếu không `terraform apply` sẽ báo lỗi credential ngay từ đầu.

## Prerequisites

* Đã hoàn thành Lab 3 (hiểu rõ VNet/Subnet/Route Table/NAT/SG bằng tay trước khi để Terraform làm hộ)
* Azure Account, credit còn khả dụng
* Azure Region: **eastus**
* Terraform >= 1.5.0
* Azure CLI đã `aws configure` với Access Key của Microsoft Entra ID / Azure RBAC User riêng cho Terraform (xem Step 0, [`docs/lab-04-hands-on.md`](./docs/lab-04-hands-on.md))
* Một Azure VM key pair đã có sẵn (dùng tạm cho test Azure VM)

## Architecture

Giống thiết kế ở Lab 3 (xem [`../lab-03a-vnet-networking-console/README.md`](../lab-03a-vnet-networking-console/README.md) cho diagram và CIDR plan đầy đủ) — Lab 4 chỉ khác ở chỗ: toàn bộ được Terraform tạo trên 1 VNet mới (CIDR giống Lab 3 vì không có lý do đổi, nhưng là VNet ID khác):

```text
Public Subnet       -> Azure NAT Gateway, network-test-ec2 (verify)
Private App Subnet  -> (trống, sẵn sàng cho Container Apps ở Lab 5)
Private Data Subnet -> (trống, sẵn sàng cho Azure Database for PostgreSQL ở bước mở rộng)
```

## Azure Services

| Service | Vai trò |
| ------- | ------- |
| VNet + Subnets + IGW + NAT + Route Tables | Network foundation, y thiết kế Lab 3 |
| NSGs | ALB SG, Container Apps SG, Azure Database for PostgreSQL SG (định nghĩa sẵn, chưa có resource nào dùng Azure Database for PostgreSQL SG vì chưa có Azure Database for PostgreSQL) |
| Azure VM (t3.micro) | `network-test-ec2`, tạm thời, chỉ để verify — giống vai trò ở Lab 3A |

## Mở rộng tiếp theo (chưa có trong code hiện tại)

Theo roadmap, bước tiếp theo của lab này (cùng số Lab 4 hoặc tách riêng nếu muốn) là thêm:

* `azure_instance` cho Wallet API (di chuyển từ default VNet của Lab 1 sang Private App Subnet)
* `azure_db_instance` cho Azure Database for PostgreSQL Flexible Server, đặt trong Private Data Subnet, `publicly_accessible = false`
* `azure_s3_bucket` + Managed Identity, giữ vai trò như Lab 1

> Known gap khi làm phần này: `DB_PASSWORD` vẫn nên truyền qua biến Terraform / env var, chưa qua Key Vault — để dành Lab 6/7 (đúng quyết định đã thống nhất, tránh loãng trọng tâm IaC).

Lab 5 (`lab-05-terraform-container-apps-platform`) đã viết sẵn skeleton Container Apps/ALB tiêu thụ output của Lab 4 — không cần đợi phần mở rộng Azure VM/Azure Database for PostgreSQL/Azure Blob Storage này xong mới làm Lab 5, vì Lab 5 chỉ cần `vpc_id` + subnet IDs + SG IDs đã có sẵn trong `outputs.tf` hiện tại.

## Estimated Cost

| Resource | Chi phí ước tính |
| -------- | ----------------- |
| Azure NAT Gateway | ~$32/tháng — tốn theo giờ, ưu tiên xoá nếu nghỉ dài |
| Azure VM t3.micro (test) | Free Tier 750h/tháng |

## Region

`eastus`

## Cleanup

* [ ] Terminate/destroy `network-test-ec2` sau khi verify (`terraform destroy -target=azure_instance.network_test`)
* [ ] `terraform destroy` khi không cần giữ toàn bộ — độc lập với Lab 1/2/3, xoá an toàn
* [ ] Kiểm tra EIP không còn unattached sau destroy
* [ ] Nếu không dùng Access Key Terraform nữa: Microsoft Entra ID / Azure RBAC → User `terraform-cli` → Deactivate/Delete Access Key

## Lessons Learned

* Terraform cần Access Key của Microsoft Entra ID / Azure RBAC User riêng — session đăng nhập Console không tự dùng được, đây là bước setup hay bị quên nhất khi mới chuyển từ Console/CLI sang Terraform.
* Để Terraform tạo nhiều subnet/route table theo AZ, dùng `count = length(var.azs)` và index-align toàn bộ list variable liên quan (`azs`, `*_subnet_cidrs`) — nếu length lệch nhau, Terraform báo lỗi rõ ngay từ `plan`, không chờ tới `apply`.
* Tách file theo concern (`main.tf` cho network, `security_groups.tf`, `test_ec2.tf` riêng) giúp dễ `terraform destroy -target` một phần mà không đụng phần còn lại.
* Vì đã làm tay ở Lab 3, đọc lại đoạn HCL này không còn cảm giác "code lạ" — mỗi resource block ánh xạ trực tiếp tới một màn hình Console đã từng bấm qua.
* Chi tiết Q&A phỏng vấn (tập trung phần Terraform/credential, không lặp lại VNet concepts đã có ở Lab 3) xem [`docs/lab-04-interview-notes.md`](./docs/lab-04-interview-notes.md).

## Trạng thái

Terraform, network layer đã viết xong (VNet + 3-tier Subnet + NAT + Route Table + SG + test Azure VM), khớp 1:1 với Lab 3A. Phần Azure VM/Azure Database for PostgreSQL/Azure Blob Storage/Microsoft Entra ID / Azure RBAC của Lab 1 chưa Terraform hoá vào đây — xem mục "Mở rộng tiếp theo". Điền `terraform.tfvars` (copy từ `.example`), xác nhận `my_ip_cidr` và `key_pair_name`, và **đã setup Access Key theo Step 0 của [`docs/lab-04-hands-on.md`](./docs/lab-04-hands-on.md)** trước khi `terraform apply`.

