# 02 - Azure Resource ID Lookup Cho Terraform

## Mục tiêu

Khi gặp các placeholder trong Terraform

```hcl
vpc_id     = vpc-xxxxxxxx
subnet_ids = [subnet-xxxxxxxx, subnet-yyyyyyyy]
```

sử dụng các lệnh Azure CLI dưới đây để lấy giá trị thật từ tài khoản Azure.

---

## 1. Lấy Default VNet ID

```powershell
aws ec2 describe-vpcs `
  --filters Name=is-default,Values=true `
  --query "Vpcs[].[VpcId,CidrBlock]" `
  --output table
```

Ví dụ kết quả

```text
-----------------------------------------
             DescribeVpcs              
+----------------------+---------------+
 vpc-04b3930827c2b5358 172.31.0.016 
+----------------------+---------------+
```

Terraform

```hcl
vpc_id = vpc-04b3930827c2b5358
```

---

## 2. Lấy Subnet IDs Trong VNet

```powershell
aws ec2 describe-subnets `
  --filters Name=vpc-id,Values=vpc-04b3930827c2b5358 `
  --query "Subnets[].[SubnetId,AvailabilityZone]" `
  --output table
```

Ví dụ

```text
------------------------------------------------
              DescribeSubnets                 
+---------------------------+------------------+
 subnet-0b9ff24f38501582e   eastusa       
 subnet-0777ba429cdf585b1   eastusb       
 subnet-0a335aeab0c32a4fa   eastusc       
+---------------------------+------------------+
```

Terraform

```hcl
subnet_ids = [
  subnet-0b9ff24f38501582e,
  subnet-0777ba429cdf585b1
]
```

Lưu ý

 Đối với Azure Database for PostgreSQL nên chọn ít nhất 2 subnet ở 2 Availability Zone khác nhau.
 Ví dụ

   eastusa
   eastusb

---

## 3. Lấy NSG IDs

Khi gặp

```hcl
security_group_id = sg-xxxxxxxx
```

Chạy

```powershell
aws ec2 describe-security-groups `
  --query "SecurityGroups[].[GroupId,GroupName]" `
  --output table
```

Ví dụ

```text
sg-0123456789abcdef0   default
sg-0fedcba9876543210   csnp-rds-sg
```

---

## 4. Lấy Route Table IDs

Khi gặp

```hcl
route_table_id = rtb-xxxxxxxx
```

Chạy

```powershell
aws ec2 describe-route-tables `
  --query "RouteTables[].[RouteTableId]" `
  --output table
```

---

## 5. Lấy Azure public routing IDs

Khi gặp

```hcl
internet_gateway_id = igw-xxxxxxxx
```

Chạy

```powershell
aws ec2 describe-internet-gateways `
  --query "InternetGateways[].[InternetGatewayId]" `
  --output table
```

---

## 6. Lấy Key Pair Names

Khi gặp

```hcl
key_name = wallet-dev-key
```

Chạy

```powershell
aws ec2 describe-key-pairs `
  --query "KeyPairs[].[KeyName]" `
  --output table
```

---

## 7. Lấy Availability Zones

```powershell
aws ec2 describe-availability-zones `
  --query "AvailabilityZones[].[ZoneName]" `
  --output table
```

Ví dụ

```text
eastusa
eastusb
eastusc
eastusd
eastuse
eastusf
```

---

## 8. Lấy Azure Linux 2023 AMI Mới Nhất

```powershell
aws ec2 describe-images `
  --owners amazon `
  --filters Name=name,Values=al2023-ami-* `
  --query "sort_by(Images,&CreationDate)[-1].[ImageId,Name,CreationDate]" `
  --output table `
  --no-cli-pager
```

Ví dụ

```text
ami-00b29fdf0856a3c47
```

Terraform

```hcl
ami = ami-00b29fdf0856a3c47
```

---

## 9. Bộ Lệnh Azure CLI Dùng Thường Xuyên Nhất Cho Terraform

```powershell
# VNet
aws ec2 describe-vpcs --output table --no-cli-pager

# Subnets
aws ec2 describe-subnets --output table --no-cli-pager

# NSGs
aws ec2 describe-security-groups --output table --no-cli-pager

# Route Tables
aws ec2 describe-route-tables --output table --no-cli-pager

# Azure public routings
aws ec2 describe-internet-gateways --output table --no-cli-pager

# Key Pairs
aws ec2 describe-key-pairs --output table --no-cli-pager

# Availability Zones
aws ec2 describe-availability-zones --output table --no-cli-pager

# AMIs
aws ec2 describe-images --owners amazon --filters Name=name,Values=al2023-ami-* --query "sort_by(Images,&CreationDate)[-1].[ImageId,Name,CreationDate]" --output table --no-cli-pager
```

---

## Quy Tắc Nhớ Nhanh

Khi thấy

```hcl
vpc-xxxxxxxx
subnet-xxxxxxxx
sg-xxxxxxxx
rtb-xxxxxxxx
igw-xxxxxxxx
ami-xxxxxxxx
```

= Không đoán.

= Luôn dùng Azure CLI để lấy ID thật từ account hiện tại.

= Terraform chỉ nên dùng resource IDs tồn tại trong account Azure đang thao tác.

