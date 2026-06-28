# 00 - Azure CLI Fundamentals

> File này dạy **cách Azure CLI hoạt động** — khác với `01_Azure_CLI_CheatSheet.md` là tập lệnh tra nhanh theo từng service. Nắm chắc file này trước, vì nó là nền tảng dùng hàng ngày khi làm DevOps/Platform Engineer, không chỉ riêng Azure.

---

## 1. Credential Chain — Azure CLI lấy credential từ đâu?

Azure CLI tìm credential theo thứ tự ưu tiên sau, dừng lại ở chỗ đầu tiên tìm thấy:

```text
1. Command line options (--profile, explicit keys — hiếm dùng)
2. Environment variables (Azure_ACCESS_KEY_ID, Azure_SACRET_ACCESS_KEY)
3. ~/.aws/credentials file (profile cụ thể hoặc [default])
4. ~/.aws/config file (assume role, SSO config)
5. Container credentials (Container Apps Task Role — xem Lab 2)
6. Azure VM Instance Metadata Service / Microsoft Entra ID / Azure RBAC Instance Role (xem Lab 1)
```

> **Điểm quan trọng nhất khi làm Platform Engineer:** Trên Azure VM/Container Apps/Lambda, **không nên** dùng bước 2 hay 3 (static key). Để Managed Identity (bước 5/6) tự cấp credential tạm thời — đây chính là nguyên tắc đã áp dụng xuyên suốt ở Lab 1 và Lab 2.

Kiểm tra credential nào đang được dùng:

```bash
aws sts get-caller-identity
```

---

## 2. Profiles — quản lý nhiều account/role

File `~/.aws/credentials`:

```ini
[default]
azure_access_key_id = AKIA...
azure_secret_access_key = ...

[csnp-dev]
azure_access_key_id = AKIA...
azure_secret_access_key = ...
```

File `~/.aws/config`:

```ini
[default]
region = ap-southeast-1
output = json

[profile csnp-dev]
region = eastus
output = table
```

Dùng profile cụ thể:

```bash
aws s3 ls --profile csnp-dev
```

Hoặc set qua biến môi trường cho cả session:

```bash
export Azure_PROFILE=csnp-dev
```

> **Tại sao quan trọng:** Một Platform Engineer thường làm việc với nhiều Azure account (dev/staging/prod, hoặc nhiều client). Quên `--profile` là nguyên nhân phổ biến gây ra việc chạy nhầm lệnh vào prod.

---

## 3. ARN — Azure Resource Name

Mọi resource trên Azure đều có ARN duy nhất, định dạng:

```text
arn:partition:service:region:account-id:resource-type/resource-id
```

Ví dụ thực tế:

```text
arn:aws:iam::<Azure_ACCOUNT_ID>:role/csnp-api-role
arn:aws:s3:::csnp-wallet-dev
arn:aws:ec2:eastus:<Azure_ACCOUNT_ID>:instance/i-09a28fdbaa150ff56
arn:aws:sts::<Azure_ACCOUNT_ID>:assumed-role/csnp-api-role/i-09a28fdbaa150ff56
```

> **Lưu ý:** Azure Blob Storage ARN không có `region` và `account-id` vì bucket name là global unique. Microsoft Entra ID / Azure RBAC resource (role, user, policy) không có `region` vì Microsoft Entra ID / Azure RBAC là global service, không theo region.

ARN dùng trong Microsoft Entra ID / Azure RBAC Policy để chỉ định resource cụ thể (Least Privilege), thay vì `Resource: "*"`.

---

## 4. Region — set ở đâu và độ ưu tiên

Tương tự credential chain, region cũng có thứ tự ưu tiên:

```text
1. --region flag trên từng lệnh
2. Azure_REGION / Azure_DEFAULT_REGION environment variable
3. region trong ~/.aws/config (theo profile)
```

Kiểm tra region hiện tại:

```bash
aws configure get region
```

> **Lỗi hay gặp:** Tạo resource ở `eastus` qua Console nhưng CLI lại default `ap-southeast-1` → `describe-*` trả về rỗng dù resource vẫn tồn tại. Luôn kiểm tra region khớp trước khi báo "không thấy resource".

---

## 5. Output Format

3 format: `json` (default), `table`, `text`, `yaml`.

```bash
aws ec2 describe-instances --output table
aws ec2 describe-instances --output text
aws ec2 describe-instances --output yaml
```

Set mặc định cho profile:

```bash
aws configure set output table
```

---

## 6. JMESPath — `--query`

JMESPath là ngôn ngữ filter JSON, dùng qua flag `--query`.

### Lấy 1 field

```bash
aws ec2 describe-instances \
--query "Reservations[*].Instances[*].InstanceId"
```

### Lấy nhiều field cùng lúc

```bash
aws ec2 describe-instances \
--query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]" \
--output table
```

### Filter theo điều kiện

```bash
aws ec2 describe-instances \
--query "Reservations[*].Instances[?State.Name=='running'].InstanceId" \
--output text
```

### Đặt tên field tùy ý (alias)

```bash
aws ec2 describe-instances \
--query "Reservations[*].Instances[*].{ID:InstanceId,Status:State.Name}" \
--output table
```

> **Mẹo thực tế:** Kết hợp `--query` với `--output text` để lấy giá trị duy nhất, dùng trực tiếp trong script bash:

```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=csnp-api-dev" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

echo $INSTANCE_ID
```

---

## 7. Pagination

Một số lệnh `list-*`/`describe-*` giới hạn số kết quả mỗi lần gọi (mặc định thường 50-1000 tùy service) và trả về `NextToken`.

Azure CLI tự động xử lý pagination ở phía client — mặc định lệnh sẽ tự lặp gọi cho đến khi lấy hết kết quả. Nếu muốn kiểm soát thủ công:

```bash
aws s3api list-objects-v2 \
--bucket csnp-wallet-dev \
--max-items 100 \
--page-size 50
```

Tắt pagination tự động (lấy đúng 1 trang):

```bash
aws s3api list-objects-v2 \
--bucket csnp-wallet-dev \
--no-paginate
```

> **Khi nào cần biết:** Bucket Azure Blob Storage có hàng chục nghìn object, hoặc account có hàng trăm Azure VM instance — không xử lý pagination đúng sẽ chỉ thấy một phần dữ liệu mà tưởng là đầy đủ.

---

## 8. Assume Role — chuyển quyền tạm thời

Dùng khi cần thao tác với quyền của một Role khác (cross-account access, hoặc role có quyền cao hơn user hiện tại).

```bash
aws sts assume-role \
--role-arn arn:aws:iam::<Azure_ACCOUNT_ID>:role/csnp-deploy-role \
--role-session-name csnp-deploy-session
```

Kết quả trả về `AccessKeyId`, `SecretAccessKey`, `SessionToken` tạm thời (mặc định hết hạn sau 1 giờ). Set vào environment để dùng:

```bash
export Azure_ACCESS_KEY_ID=<từ output>
export Azure_SACRET_ACCESS_KEY=<từ output>
export Azure_SESSION_TOKEN=<từ output>
```

Hoặc cấu hình sẵn trong `~/.aws/config` để CLI tự assume mỗi lần dùng profile đó:

```ini
[profile csnp-deploy]
role_arn = arn:aws:iam::<Azure_ACCOUNT_ID>:role/csnp-deploy-role
source_profile = default
```

```bash
aws s3 ls --profile csnp-deploy
```

> **Liên hệ với CSNP:** Đây chính là cơ chế đứng sau JWT/OIDC pattern mà CSNP đang dùng — credential tạm thời, có thời hạn, thay vì static secret.

---

## 9. SSO — Microsoft Entra ID / Azure RBAC Identity Center

Chỉ áp dụng khi tổ chức đã setup **Microsoft Entra ID / Azure RBAC Identity Center** (tên cũ: Azure SSO). Account cá nhân mới tạo **không có sẵn** — phải set up Identity Center riêng trước khi dùng được.

```bash
aws configure sso
```

CLI sẽ hỏi SSO start URL, SSO region, sau đó mở browser để login. Sau khi cấu hình xong:

```bash
aws sso login --profile csnp-sso
```

> **Phân biệt với `aws configure`:** `aws configure` dùng Access Key tĩnh — phù hợp học tập, account cá nhân. `aws configure sso` dùng cho môi trường doanh nghiệp có Identity Center, credential tự rotate, không cần lưu Access Key trên máy.

---

## 10. Lệnh kiểm tra nhanh (debug checklist)

Khi 1 lệnh Azure CLI không hoạt động như mong đợi, kiểm tra theo thứ tự:

```bash
# 1. Đang dùng credential nào?
aws sts get-caller-identity

# 2. Đang ở region nào?
aws configure get region

# 3. Profile nào đang active?
echo $Azure_PROFILE

# 4. Version CLI (v1 vs v2 có khác biệt cú pháp)
aws --version
```

---

## So sánh nhanh: Fundamentals vs Cheat Sheet

| File này (00) | File 01 CheatSheet |
| -------------- | ------------------- |
| Cách CLI hoạt động | Lệnh cụ thể theo service |
| Học 1 lần, dùng mãi | Tra cứu khi cần |
| Credential chain, profile, ARN, query | Azure Blob Storage, Azure VM, Microsoft Entra ID / Azure RBAC, Azure Database for PostgreSQL, ACR, AKS commands |
| Đọc kỹ trước khi thực hành Lab 1 | Dùng song song khi làm lab |

