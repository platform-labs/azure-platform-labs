# Azure Hands-on Lab #4

## Deliberate practice loop

1. **Mental model:** từ Lab 3, tự viết resource graph và dự đoán Terraform create order.
2. **Console discovery:** map VNet/Subnet/Route Table/NAT/SG fields với HCL; không tạo stack thứ hai.
3. **Implementation:** `init` → tfvars → `plan` → đọc plan → `apply`; không dùng `-target` cho full stack.
4. **CLI verification:** đối chiếu Terraform outputs với Azure VM/VNet describe commands.
5. **Failure drill:** đổi route hoặc SG có kiểm soát, đọc plan trước khi apply và xác minh symptom.
6. **Rebuild without guide:** destroy rồi viết lại network chỉ từ README/CIDR plan.
7. **Cleanup/cost audit:** NAT/EIP/test Azure VM trước; xác nhận remote state vẫn đúng sau destroy.
8. **Interview recap:** giải thích dependency inference, state, drift và remote locking.

Quy tắc luyện nhiều vòng: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

## Terraform Platform Foundation — setup + apply

### Mục tiêu

Terraform-hoá toàn bộ network đã làm tay ở Lab 3, trên **VNet mới** (không tái sử dụng VNet của Lab 3A). Đây là lab đầu tiên Terraform thực sự gọi Azure API thay mặt mình — nên trước khi đụng tới bất kỳ file `.tf` nào, phải có credential đúng cách. Đây là phần hay bị bỏ qua nhất khi tự học Terraform.

---

# Step 0 - Setup Azure credentials cho Terraform (bắt buộc, làm trước tiên)

## Vì sao không dùng "Azure Login" (SSO / Console login session)?

Khi đăng nhập Console qua trình duyệt (kể cả qua Microsoft Entra ID / Azure RBAC Identity Center / Azure SSO), Azure cấp một **session token tạm thời gắn với trình duyệt** — không có access key/secret key để Terraform (chạy local, qua CLI) dùng lại trực tiếp trừ khi cấu hình thêm SSO profile. Nếu chỉ "login" qua web rồi chạy `terraform apply`, Terraform sẽ báo lỗi kiểu:

```
Error: error configuring Terraform Azure Provider: no valid credential sources for Terraform Azure Provider found
```

Lab này dùng cách đơn giản nhất cho máy cá nhân: tạo **Microsoft Entra ID / Azure RBAC User với Access Key** riêng cho Terraform, không dùng chung với session Console.

## 0.1 Tạo Microsoft Entra ID / Azure RBAC User riêng cho Terraform

Console: Microsoft Entra ID / Azure RBAC → Users → **Create user**

* User name: `terraform-cli`
* Không tick "Provide user access to the Azure Management Console" — user này chỉ dùng để gọi API, không cần login web

## 0.2 Gắn quyền cho user

Cách nhanh cho lab cá nhân (không phải production):

* Attach policies directly → `AdministratorAccess`

> Đây là lựa chọn lab-only, giống cách Lab 1 đã dùng `AmazonAzure Blob StorageFullAccess` cho nhanh rồi note rõ là tạm. Production thật phải scope quyền theo least-privilege (chỉ Azure VM/VNet/Container Apps/Azure Database for PostgreSQL/Microsoft Entra ID / Azure RBAC cần dùng), nhưng với tài khoản cá nhân học Azure, `AdministratorAccess` tránh việc apply nửa chừng rồi vướng lỗi thiếu quyền không đáng có.

## 0.3 Tạo Access Key

Sau khi tạo User → vào User vừa tạo → tab **Security credentials** → **Create access key**

* Use case: chọn **Command Line Interface (CLI)**
* Tick xác nhận hiểu rủi ro, Next
* Description tag: `terraform-local` (tuỳ chọn)
* **Create access key**

Màn hình hiện ra **Access key** và **Secret access key**. Đây là lần duy nhất Secret access key hiển thị đầy đủ — copy ngay hoặc download file `.csv`, không có cách xem lại sau.

## 0.4 Configure Azure CLI với Access Key này

```bash
aws configure
```

Nhập theo thứ tự:

```
Azure Access Key ID [None]: <paste access key>
Azure Secret Access Key [None]: <paste secret key>
Default region name [None]: eastus
Default output format [None]: json
```

Lệnh này ghi vào `~/.aws/credentials` và `~/.aws/config`. Terraform's Azure Provider tự đọc từ đây mà không cần khai báo gì thêm trong code.

## 0.5 Verify credential hoạt động

```bash
aws sts get-caller-identity
```

Kỳ vọng: trả về JSON có `Account`, `Arn` đúng là `arn:aws:iam::<account-id>:user/terraform-cli` — không phải role của session SSO.

## Bảo mật Access Key

* **Không commit** Access Key/Secret Key vào git, vào file `.tf`, hoặc bất kỳ đâu trong source code
* `~/.aws/credentials` nằm ngoài git repo (thư mục home), an toàn theo cách lưu mặc định
* Nếu lỡ làm rò Access Key (commit nhầm, share nhầm): vào Microsoft Entra ID / Azure RBAC → User → Security credentials → **Deactivate** rồi **Delete** Access Key đó ngay, tạo key mới
* Lab xong, nếu không dùng nữa: xoá Access Key (giữ User nếu định dùng lại sau) hoặc xoá luôn User

---

# Step 1 - terraform init

```bash
cd lab-04-terraform-platform-foundation/terraform
terraform init
```

Lệnh này tải Azure Provider plugin (`hashicorp/aws ~> 5.0` theo khai báo trong `backend.tf`) — không gọi Azure API nào, chỉ chuẩn bị local.

---

# Step 2 - Điền terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Điền 2 giá trị bắt buộc:

```hcl
my_ip_cidr    = "<ip-cua-ban>/32"   # lấy bằng: curl -s https://checkip.amazonaws.com
key_pair_name = "<ten-key-pair-da-co>"
```

Nếu chưa có key pair: Console → Azure VM → Key Pairs → Create key pair → download `.pem`, `chmod 400 file.pem`.

---

# Step 3 - terraform plan

```bash
terraform plan
```

Đọc kỹ output trước khi apply — kiểm tra số lượng resource sẽ tạo (`Plan: N to add, 0 to change, 0 to destroy`), không nên có dòng `destroy` nào ở lần plan đầu tiên trên một state mới.

---

# Step 4 - terraform apply

```bash
terraform apply
```

Gõ `yes` khi được hỏi xác nhận. Azure NAT Gateway sẽ là resource lâu nhất (vài phút) — đây là điều đã biết từ Lab 3A.

---

# Step 5 - Verify

```bash
terraform output
```

So sánh các output (`vpc_id`, `public_subnet_ids`, `private_app_subnet_ids`, `private_data_subnet_ids`, `nat_gateway_id`, `alb_security_group_id`, `ecs_security_group_id`, `rds_security_group_id`) với những gì đã thấy trên Console ở Lab 3A — cấu trúc giống, chỉ khác VNet ID vì đây là VNet mới.

Verify network hoạt động đúng theo đúng checklist đã dùng ở Lab 3 — xem [`docs/lab-04-verification.md`](#) hoặc tái dùng cách kiểm tra ở `lab-03a-vnet-networking-console/docs/lab-03-verification.md` (route table, SSH, NAT) áp dụng cho VNet mới này.

---

# Cleanup

```bash
terraform destroy
```

Sau khi destroy xong, nếu không cần Access Key nữa: Microsoft Entra ID / Azure RBAC → User `terraform-cli` → Security credentials → Deactivate/Delete key.

---

# Lessons Learned

* Azure Console login (qua trình duyệt) và Terraform credential là 2 thứ tách biệt — Terraform cần Access Key/Secret Key của Microsoft Entra ID / Azure RBAC User (hoặc Managed Identity qua AssumeRole/SSO profile, phức tạp hơn), không tự dùng được session đăng nhập web.
* `AdministratorAccess` cho user `terraform-cli` là lựa chọn lab-only, có ý thức đánh đổi tốc độ học lấy bảo mật — không áp dụng cho production hoặc tài khoản công ty.
* Access Key chỉ hiển thị Secret đầy đủ một lần duy nhất lúc tạo — mất thì phải tạo key mới, không xem lại được.
* Chi tiết Q&A phỏng vấn xem [`docs/lab-04-interview-notes.md`](./lab-04-interview-notes.md).

