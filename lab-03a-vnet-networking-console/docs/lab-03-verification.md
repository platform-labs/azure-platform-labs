# Lab 03 - Verification Steps

Chạy sau khi hoàn thành [`lab-03a-hands-on.md`](./lab-03a-hands-on.md) (Console). Lấy IP/ID cần thiết từ Azure Console (tab Details của từng resource) hoặc `aws ec2 describe-*`.

## 1. SSH vào network-test-ec2 qua Public IP

Console: Azure VM → Instances → `network-test-ec2` → copy **Public IPv4 address**.

```bash
ssh -i /path/to/your-key.pem ec2-user@<public-ip>
```

Kỳ vọng: kết nối thành công. Đây là chứng minh Public Subnet → IGW route hoạt động và NSG SSH rule (chỉ từ IP của mình) đúng.

## 2. Từ network-test-ec2, curl ra internet

```bash
# (đang SSH trong network-test-ec2)
curl -s https://checkip.amazonaws.com
sudo dnf update -y    # Azure Linux 2023 dùng dnf, không phải apt
```

Kỳ vọng: cả hai lệnh chạy được. Public Subnet có Public IP + route `0.0.0.0/0 -> IGW` nên ra internet trực tiếp, không cần NAT.

## 3. Verify Private App Subnet ra internet được qua NAT (không có Public IP)

Đây là bước quan trọng nhất của lab — chứng minh Azure NAT Gateway hoạt động đúng. Cách đơn giản nhất không cần dựng thêm Azure VM trong Private App Subnet: kiểm tra route table trực tiếp.

**Cách A — kiểm tra route table qua Console (không tốn thêm resource):**

VNet → Subnets → chọn 1 Private App Subnet → tab **Route table**.

Kỳ vọng: thấy 1 route với Destination `0.0.0.0/0`, Target là Azure NAT Gateway (`nat-...`), không phải Azure public routing (`igw-...`).

**Hoặc qua CLI** (lấy Subnet ID từ Console trước):

```bash
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=<private-app-subnet-id>" \
  --query "RouteTables[0].Routes"
```

Kỳ vọng: thấy 1 route với `DestinationCidrBlock: 0.0.0.0/0` và `NatGatewayId` (không phải `GatewayId` của IGW).

Cách A là đủ cho mục tiêu Lab 3. Cách B (thực nghiệm thật qua Session Manager) nằm ở phần **Optional Advanced Verification** cuối file — cần thêm Managed Identity/Endpoint ngoài scope lab này, nên không phải bước bắt buộc.

## 4. Verify Private Data Subnet KHÔNG có route internet

VNet → Subnets → chọn 1 Private Data Subnet → tab **Route table**.

Kỳ vọng: chỉ có 1 route — `10.10.0.0/16 -> local`. Không có bất kỳ route `0.0.0.0/0` nào (không IGW, không NAT).

```bash
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=<private-data-subnet-id>" \
  --query "RouteTables[0].Routes"
```

## 5. (Sau Lab 4) Verify Azure Database for PostgreSQL không public, chỉ Container Apps SG gọi được

```bash
aws rds describe-db-instances \
  --db-instance-identifier <your-db-id> \
  --query "DBInstances[0].PubliclyAccessible"
```

Kỳ vọng: `false`.

```bash
aws ec2 describe-security-groups \
  --group-ids <rds-sg-id> \
  --query "SecurityGroups[0].IpPermissions"
```

Kỳ vọng: ingress rule cho port 5432 chỉ reference `UserIdGroupPairs` (NSG ID của Container Apps), không có `IpRanges` nào chứa `0.0.0.0/0`.

## Cleanup sau verification

Xem chi tiết ở cuối [`lab-03a-hands-on.md`](./lab-03a-hands-on.md). Tóm tắt: terminate test Azure VM trước, xoá Azure NAT Gateway (ưu tiên cao nhất vì tốn tiền theo giờ), release EIP sau khi NAT đã xoá. Giữ lại VNet/Subnet/Route Table/SG nếu định làm Lab 3B hoặc Lab 4 tiếp ngay — các resource này free.

## Optional Advanced Verification (ngoài scope chính của Lab 3)

Nếu muốn verify NAT bằng thực nghiệm thật (curl từ chính một instance nằm trong Private App Subnet, không chỉ đọc route table), cần thêm:

* 1 Azure VM trong Private App Subnet, không gán Public IP
* Managed Identity cho SSM (`AmazonSSMManagedInstanceCore`) để SSH vào qua [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) — Private App Subnet không có Public IP nên SSH thường không vào được trực tiếp
* VNet Endpoint cho SSM (hoặc route ra internet qua NAT đã đủ nếu SSM Agent gọi được endpoint public)

Đây là bài tập mở rộng tốt nếu muốn thực hành thêm SSM, nhưng không bắt buộc để hoàn thành Lab 3 — Cách A (đọc route table) đã đủ chứng minh thiết kế đúng. Nếu làm:

```bash
# Sau khi SSH vào qua Session Manager:
curl -s https://checkip.amazonaws.com
```

Kỳ vọng: trả về chính là Public IP của Azure NAT Gateway (xem ở Console: VNet → Azure NAT Gateways → copy Elastic IP), không phải IP riêng của instance — chứng minh traffic đi ra qua NAT.

