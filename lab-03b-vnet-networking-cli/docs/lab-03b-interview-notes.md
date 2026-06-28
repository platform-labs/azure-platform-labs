# Lab 3B - Azure CLI & API Deep Dive (Interview Notes)

## 1. Tại sao cần học CLI khi đã có Console?

Có 3 lý do:

### 1.1 **Transition to Infrastructure as Code**

Console → CLI → Terraform là chuỗi học:

| Level | Cách làm | Học được |
| --- | --- | --- |
| Console (UI) | Click button | Resource concepts |
| CLI (API) | Gọi API thủ công | API structure, dependency |
| Terraform (IaC) | Declare in code | Automation, idempotency |

Console che giấu API complexity → bạn không biết "tạo VNet" là gọi bao nhiêu API, API trả gì, phải gọi theo thứ tự nào.

CLI phơi bày rõ: 1 API per command → bạn học thấu đáo.

### 1.2 **Automation at Scale**

Khi cần tạo 100 VNet, 1000 subnet, click button không khả thi → phải script CLI / Terraform.

Lab 3B dạy bạn: `aws ec2 create-subnet` có thể loop, pipe output vào biến, dùng trong shell script.

### 1.3 **Debugging**

Console error message thường vague: "Failed to create subnet" — không nói lý do.

CLI error trả đầy đủ: `DependencyViolation: The vpc has dependencies...` → dễ debug.

### Keywords

* Console vs CLI vs IaC
* Automation
* Scalability
* Debugging
* Learning Progression

---

## 2. Azure CLI Command Structure

Tất cả Azure CLI command đều theo pattern:

```bash
aws <service> <action> <--parameters>
```

### Ví dụ

| Command | Phân tích |
| --- | --- |
| `aws ec2 create-vpc --cidr-block 10.20.0.0/16` | service=`ec2`, action=`create-vpc`, param=`--cidr-block` |
| `aws ec2 describe-vpcs --vpc-ids vpc-123` | service=`ec2`, action=`describe-vpcs` (get list + filter) |
| `aws s3 cp file.txt s3://bucket/` | service=`s3`, action=`cp` (copy) |
| `aws iam create-user --user-name alice` | service=`iam`, action=`create-user` |

### Action Naming Convention

* **Create**: `create-*` (CreateVpc → `create-vpc`)
* **Get/List**: `describe-*` (DescribeVpcs → `describe-vpcs`) — **Aws sử dụng `describe`, không `get` hay `list`**
* **Update**: `modify-*` (ModifyVpc → `modify-vpc`)
* **Delete**: `delete-*` (DeleteVpc → `delete-vpc`)

### Keywords

* Command Pattern
* Service vs Action
* Parameter Naming
* Azure API Mapping

---

## 3. Output Format & Parsing

### 3.1 **JSON Output (Default)**

```bash
aws ec2 create-vpc --cidr-block 10.20.0.0/16
```

Trả JSON:

```json
{
    "Vpc": {
        "VpcId": "vpc-123",
        "CidrBlock": "10.20.0.0/16",
        ...
    }
}
```

### 3.2 **Query with JMESPath**

Extract chỉ `VpcId`:

```bash
aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --query "Vpc.VpcId" \
  --output text
```

Output: `vpc-123` (string thuần, không JSON)

### 3.3 **For Automation**

Trong script, thường cần extract ID để dùng lệnh tiếp theo:

```bash
# Bash script
VNet_ID=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --query "Vpc.VpcId" --output text)

aws ec2 create-subnet --vpc-id $VNet_ID --cidr-block 10.20.1.0/24
```

Đây chính là cơ sở của các automation script, infrastructure-as-code tools.

### Keywords

* JSON Output
* JMESPath Query
* Text Output
* Piping & Scripting
* Output Formatting

---

## 4. Resource ID Management

### 4.1 **Console tự lưu context, CLI không**

| Interface | Context | Ảnh hưởng |
| --- | --- | --- |
| Console | "Bạn đang trong VNet vpc-123" → dropdown hiển thị mọi resource trong đó | Bạn không cần nhớ ID |
| CLI | "Bạn chạy command tách rời" → không có context | **Bạn phải lưu & truyền ID thủ công** |

### 4.2 **Lưu ID trong Variable**

```bash
# macOS / Linux / WSL2 (Bash)
export VNet_ID=vpc-123
echo $VNet_ID

# Windows PowerShell
$env:VNet_ID = "vpc-123"
$env:VNet_ID
```

### 4.3 **Lưu trong File**

Nếu chạy từ script, lưu ID trong file để tái sử dụng sau:

```bash
# Create VNet, lưu ID vào file
aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --query "Vpc.VpcId" --output text > vpc-id.txt

# Đọc lại từ file ở lệnh tiếp theo
VNet_ID=$(cat vpc-id.txt)
aws ec2 create-subnet --vpc-id $VNet_ID ...
```

### 4.4 **Query lại từ Azure nếu mất**

Nếu terminal close, biến mất → query lại:

```bash
# Tìm VNet theo CIDR block
aws ec2 describe-vpcs --filters "Name=cidr-block,Values=10.20.0.0/16" \
  --query "Vpcs[0].VpcId" --output text
```

**Đây chính là lý do Terraform cần `state` file** — để không mất ID, có thể recreate/destroy resource.

### Keywords

* Resource Identity
* ID Management
* Environment Variables
* State Tracking
* Persistent Storage

---

## 5. API Dependency & Order of Operations

### 5.1 **Create Order**

```
VNet (tạo trước)
  ↓ (Subnet phải nằm trong VNet)
Subnet
  ↓ (Route Table phải nằm trong VNet)
Route Table
  ↓ (Association gắn Route Table vào Subnet)
Route Table Association
  ↓ (Route add traffic rule vào Route Table)
Route (thêm 0.0.0.0/0 → IGW)
```

Nếu tạo sai thứ tự (ví dụ Subnet trước VNet) → lỗi:

```
InvalidParameterValue: The vpc ID 'vpc-123' does not exist
```

### 5.2 **Delete Order** (Ngược lại)

```
Route (xoá trước)
  ↓
Route Table Association (disassociate)
  ↓
Route Table (xoá)
  ↓
Subnet (xoá)
  ↓
VNet (xoá cuối)
```

Nếu xoá sai thứ tự (ví dụ VNet trước Subnet) → lỗi:

```
DependencyViolation: The vpc 'vpc-123' has dependencies and cannot be deleted.
```

### 5.3 **Why Console Hides This**

Console UI tự chặn nút Delete nếu còn dependency:

* Khi bạn click "Delete VNet" button → Console check: "Còn Subnet?" → disable button nếu có → buộc bạn xoá Subnet trước
* CLI không — nếu bạn gọi `delete-vpc` với VNet còn Subnet, Azure báo lỗi

**CLI dạy bạn dependency rõ ràng hơn — và đây chính là khái niệm Terraform dùng trong "dependency graph".**

### Keywords

* Dependency Graph
* Creation Order
* Deletion Order
* Resource Relationships
* Parent-Child Resources

---

## 6. Filters & Queries

### 6.1 **Describe (List All)**

```bash
aws ec2 describe-vpcs
```

Trả **toàn bộ** VNet trong account (có thể rất nhiều).

### 6.2 **Filter by Property**

```bash
aws ec2 describe-vpcs --filters "Name=cidr-block,Values=10.20.0.0/16"
```

Chỉ trả VNet có CIDR = `10.20.0.0/16`.

### 6.3 **Filter Syntax**

```
--filters "Name=property,Values=value1,value2"
```

Hỗ trợ **AND** (mặc định, multiple filters) nhưng **không hỗ trợ OR** (phải query 2 lần union):

```bash
# VNet có CIDR = 10.0.0.0/16 AND State = available
aws ec2 describe-vpcs \
  --filters \
    "Name=cidr-block,Values=10.0.0.0/16" \
    "Name=vpc-state,Values=available"
```

### Keywords

* Filters
* Query Results
* JMESPath
* AND vs OR
* Output Formatting

---

## 7. Idempotency & Re-running Commands

### 7.1 **Problem**

```bash
aws ec2 create-vpc --cidr-block 10.20.0.0/16

# Chạy lại lệnh trên → lỗi!
# InvalidVpcID.Duplicate: VNet with CIDR 10.20.0.0/16 already exists
```

Chạy `create` 2 lần → lỗi duplicate. Không idempotent.

### 7.2 **Solution**

Kiểm tra trước tạo:

```bash
VNet=$(aws ec2 describe-vpcs \
  --filters "Name=cidr-block,Values=10.20.0.0/16" \
  --query "Vpcs[0].VpcId" --output text)

if [ "$VNet" = "None" ]; then
  aws ec2 create-vpc --cidr-block 10.20.0.0/16
else
  echo "VNet already exists: $VNet"
fi
```

### 7.3 **Terraform Handles This**

```hcl
resource "azure_vpc" "main" {
  cidr_block = "10.20.0.0/16"
}

# Chạy lần 1: tạo VNet
# terraform apply
#   → Creates azure_vpc.main (vpc-123)

# Chạy lần 2: không làm gì (idempotent)
# terraform apply
#   → No changes (VNet đã tồn tại, cấu hình không đổi)
```

Terraform tự quản lý idempotency thông qua state file.

### Keywords

* Idempotency
* Create vs Update
* Checking Before Creating
* State Management
* Terraform Advantages

---

## 8. Credential Management in CLI

### 8.1 **How CLI Authenticate**

```bash
aws sts get-caller-identity
```

CLI tìm credential theo thứ tự (first match wins):

1. **Command-line option**: `--profile`, `--access-key-id`, `--secret-access-key`
2. **Environment variable**: `$Azure_PROFILE`, `$Azure_ACCESS_KEY_ID`, `$Azure_SACRET_ACCESS_KEY`
3. **Credential file**: `~/.aws/credentials` (từ `aws configure`)
4. **Microsoft Entra ID / Azure RBAC Instance Profile** (nếu chạy trên Azure VM)
5. **Microsoft Entra ID / Azure RBAC Identity Center** (nếu setup SSO)

### 8.2 **aws configure**

```bash
aws configure

# Nhập:
# Azure Access Key ID: AKIAIOSFODNN7EXAMPLE
# Azure Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region: eastus
# Default output format: json
```

Lưu vào `~/.aws/credentials` (macOS/Linux) hoặc `%UserProfile%\.aws\credentials` (Windows).

### 8.3 **Multiple Profiles**

```bash
# Tạo profile "dev"
aws configure --profile dev

# Dùng profile "dev"
aws ec2 describe-vpcs --profile dev
```

Hữu ích khi có multiple Azure account.

### Keywords

* Credential Priority
* aws configure
* Environment Variables
* Microsoft Entra ID / Azure RBAC Identity Center
* Multi-account Setup

---

## 9. Common CLI Mistakes

| Lỗi | Nguyên nhân | Cách sửa |
| --- | --- | --- |
| `InvalidVpcID.NotFound` | VNet ID sai hoặc mất (biến `$VNet_ID` trống) | Check `echo $VNet_ID`, query lại từ Azure |
| `DependencyViolation` | Xoá resource khi còn dependent resource | Xoá theo thứ tự ngược |
| `UnauthorizedOperation` | Microsoft Entra ID / Azure RBAC user không có permission | Kiểm tra Microsoft Entra ID / Azure RBAC policy, cần quyền `ec2:*` |
| `InvalidParameterValue` | Parameter sai format (CIDR không valid) | Check Azure doc, ví dụ CIDR phải là x.x.x.x/yy |
| `You are not authorized` | Credential không hợp lệ hoặc key bị revoke | Chạy `aws sts get-caller-identity`, check credential |

### Keywords

* Troubleshooting
* Error Messages
* Debugging
* Common Pitfalls

---

## 10. Lab 3B → Lab 4 Progression

### Lab 3B (CLI) dạy:

* API structure: create-vpc, create-subnet, ...
* Dependency management: thứ tự tạo/xoá
* Context management: lưu ID, truyền thủ công
* Filtering & querying

### Lab 4 (Terraform) sẽ:

* Khai báo resource trong HCL (không command)
* Terraform tự tính dependency graph → thứ tự tạo/xoá tự động
* Terraform state quản lý ID → bạn không cần export variable
* Terraform plan → verify trước apply

**Từ Lab 3B, bạn sẽ thấy ngay tại sao Lab 4 (Terraform) tiện hơn:**
* Không cần 5 lệnh riêng lẻ → 1 file HCL
* Không cần lưu ID → terraform state tự quản lý
* Không cần nhớ thứ tự xoá → `terraform destroy` tự đảo ngược dependency

### Keywords

* Learning Progression
* CLI → IaC
* Abstraction Levels
* Efficiency Gains
* Terraform Benefits

