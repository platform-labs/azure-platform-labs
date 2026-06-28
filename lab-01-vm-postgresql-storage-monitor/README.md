# Lab 01 - Azure VM + Azure Database for PostgreSQL Flexible Server + Azure Blob Storage + Managed Identity + Azure Monitor

## Mục tiêu

Deploy Wallet API (minimal API .NET, không phải CSNP Wallet thật) lên Azure. Sau lab này cần hiểu được:

* Managed Identity (thay cho Access Key)
* Azure VM
* NSG
* Azure Database for PostgreSQL Flexible Server
* Azure Blob Storage
* Azure Monitor Logs

## Prerequisites

* Azure Account, credit còn khả dụng
* Azure Region: **eastus**
* .NET SDK 10 cài sẵn trên máy local

> Lab dùng `Lab01.WalletMinimal` — minimal API .NET tạo riêng cho lab, không dùng Wallet API thật từ CSNP vì CSNP có nhiều dependency (RabbitMQ, Redis, Kafka) chưa cần trong lab này.

## Architecture

```text
                 Internet
                      |
                      v
               NSG (csnp-ec2-sg)
                      |
                      v
                 Azure VM t3.micro
                      |
       +--------------+-------------+
       |                            |
       v                            v
  Azure Database for PostgreSQL Flexible Server               Azure Blob Storage Bucket
  (csnp-rds-sg)             (csnp-wallet-dev)
  Private, no public access

                      |
                      v
               Azure Monitor Logs
               (csnp-wallet-api)
```

## Azure Services

| Service | Vai trò |
| ------- | ------- |
| Managed Identity | Cấp quyền cho Azure VM gọi Azure Blob Storage/Azure Monitor, không dùng static Access Key |
| Azure VM (t3.micro) | Chạy Wallet API |
| NSG | `csnp-ec2-sg` (SSH chỉ từ My IP), `csnp-rds-sg` (chỉ nhận từ Azure VM SG) |
| Azure Database for PostgreSQL Flexible Server (db.t3.micro) | Database, private, không public access |
| Azure Blob Storage | Object storage cho file upload |
| Azure Monitor Logs | Log group `csnp-wallet-api` |

## Estimated Cost

| Resource | Chi phí ước tính |
| -------- | ----------------- |
| Azure VM t3.micro | Free Tier 750h/tháng |
| Azure Database for PostgreSQL db.t3.micro | Free Tier 750h/tháng |
| EBS Volume | Kiểm tra sau khi terminate, xóa nếu state = available |

> Azure NAT Gateway không dùng trong lab này (sẽ ~$32/tháng nếu có). Set Azure Budget alert ở $10.

## Region

`eastus`

## Terraform inputs

Terraform state của Lab 1 được lưu trên shared labs Azure Blob Storage backend tại `aws/lab-01/terraform.tfstate`. Chạy [`../bootstrap/`](../bootstrap/) trước lần `terraform init` đầu tiên; không dùng bucket/key production.

Trước khi chạy Terraform, vào thư mục `terraform/` va copy file example:

```powershell
Set-Location .\terraform
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Sau đó lấy Default VNet ID của account trong đúng region lab:

```bash
aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[*].[VpcId,CidrBlock]" \
  --output table \
  --region eastus
```

Nếu chạy bằng PowerShell:

```powershell
aws ec2 describe-vpcs `
  --filters "Name=is-default,Values=true" `
  --query "Vpcs[*].[VpcId,CidrBlock]" `
  --output table `
  --region eastus
```

Lấy tất cả subnet trong Default VNet vừa tìm được:

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxx" \
  --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" \
  --output table \
  --region eastus
```

PowerShell:

```powershell
aws ec2 describe-subnets `
  --filters "Name=vpc-id,Values=vpc-xxxxxxxx" `
  --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" `
  --output table `
  --region eastus
```

Điền các giá trị lấy được vào `terraform.tfvars`:

```hcl
vpc_id     = "vpc-xxxxxxxx"
subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
```

Azure Database for PostgreSQL cần ít nhất 2 subnet, nên chọn 2 subnet ở 2 Availability Zone khác nhau nếu Default VNet có sẵn.

## Cleanup

* [ ] Terminate Azure VM instance
* [ ] Delete Azure Database for PostgreSQL instance (skip final snapshot, đây là lab)
* [ ] Empty + delete Azure Blob Storage bucket `csnp-wallet-dev`
* [ ] Xóa Azure Monitor log group `csnp-wallet-api`
* [ ] Verify EBS volume không còn ở state "available"
* [ ] Nếu chạy qua Terraform: `terraform destroy` trong `terraform/`

## Lessons Learned

* Managed Identity dùng temporary credentials (qua IMDS), Azure tự rotate — không cần quản lý secret thủ công như Access Key.
* Azure Database for PostgreSQL NSG nên reference NSG của Azure VM, không phải theo IP — vẫn đúng kể cả khi IP của Azure VM đổi.
* Chi tiết đầy đủ + Q&A phỏng vấn xem [`docs/lab-01-hands-on.md`](./docs/lab-01-hands-on.md) và [`docs/lab-01-interview-notes.md`](./docs/lab-01-interview-notes.md).

## Security note

Lab này ban đầu có file `wallet-dev-key.pem` (Azure VM key pair private key) đi kèm. File đó **không** được đưa vào cấu trúc này và không bao giờ nên commit vào git. Nếu file `.pem` đó đã từng nằm trong một thư mục được track bởi git (kể cả local), coi như key đã lộ — vào Azure Console xoá key pair cũ và tạo key pair mới cho lần chạy lại lab.

## Trạng thái

Lab đã làm thủ công qua Console (xem `docs/lab-01-hands-on.md`). `terraform/` hiện đã dựng lại phần hạ tầng chính tương đương Console: Managed Identity/Instance Profile, Azure VM, NSGs, Azure Database for PostgreSQL Flexible Server private, Azure Blob Storage private + versioning, Azure Monitor Log Group và Azure VM bootstrap cho Azure Monitor Agent/runtime/log directory. Tên resource trong Terraform được derive từ `project_name` để dễ chạy lại lab nhiều lần. Trước khi chạy vẫn cần điền `terraform.tfvars` (copy từ `.example`) và xác nhận lại `vpc_id`/`subnet_ids`/`my_ip_cidr`; phần publish/copy artifact WalletMinimal lên Azure VM vẫn làm theo bước deploy trong hands-on doc.



