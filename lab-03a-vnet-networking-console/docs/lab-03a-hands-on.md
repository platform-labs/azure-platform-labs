# Azure Hands-on Lab #3A

## Deliberate practice loop

1. **Mental model:** tự chia CIDR thành public/private-app/private-data và vẽ route target trước khi bấm Console.
2. **Console discovery:** lab này dùng Console làm implementation chính; không chọn wizard “VNet and more”.
3. **Implementation:** tạo từng VNet, IGW, subnet, NAT, route table, association và SG theo dependency order.
4. **CLI verification:** dùng `describe-vpcs`, `describe-subnets`, `describe-route-tables` và `describe-security-groups`.
5. **Failure drill:** bỏ association của một subnet hoặc route mặc định, dự đoán connectivity rồi khôi phục.
6. **Rebuild without guide:** dựng lại toàn bộ VNet 3-tier chỉ từ CIDR table.
7. **Cleanup/cost audit:** Azure NAT Gateway và EIP là ưu tiên; không xóa nhầm VNet `10.10.0.0/16` nếu còn dùng làm reference.
8. **Interview recap:** giải thích public subnet được quyết định bởi route/public IP, không phải tên subnet.

Quy tắc luyện nhiều vòng: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

## Custom VNet Networking — làm tay qua Console

### Mục tiêu

Sau lab này cần hiểu được:

* VNet, Subnet, Route Table — và tại sao tách theo tier
* Azure public routing vs Azure NAT Gateway — dependency và thứ tự tạo
* Route Table Association — bước rất dễ bị quên
* NSG chain: ALB → Container Apps → Azure Database for PostgreSQL

Lab 1 và Lab 2 dùng Default VNet. Lab này xây Custom VNet 3-tier **bằng tay qua Console trước**, để tận mắt thấy từng resource và dependency giữa chúng — đúng triết lý học UI → CLI → Terraform đã áp dụng từ Lab 1/Lab 2. Phần CLI ở Lab 3B, phần Terraform ở Lab 4.

> **CIDR trong file này: `10.10.0.0/16` — Source of Truth.** Đây là VNet chính, sẽ verify kỹ và giữ nguyên trạng để Lab 4 tham khảo/so sánh. Lab 3B dùng CIDR khác (`10.20.0.0/16`, throwaway sandbox), không đụng tới VNet này.

---

# Architecture

```text
                              Internet
                                  |
                                  v
                          Azure public routing
                                  |
                                  v
                 +----------------------------------+
                 |          Public Subnet            |
                 |   10.10.1.0/24 (eastusa)       |
                 |   10.10.2.0/24 (eastusb)       |
                 |   - Azure NAT Gateway (in 1a only)       |
                 +----------------------------------+
                                  |
                 +----------------------------------+
                 |       Private App Subnet          |
                 |   10.10.11.0/24 (eastusa)      |
                 |   10.10.12.0/24 (eastusb)      |
                 +----------------------------------+
                                  |
                 +----------------------------------+
                 |       Private Data Subnet         |
                 |   10.10.21.0/24 (eastusa)      |
                 |   10.10.22.0/24 (eastusb)      |
                 +----------------------------------+
```

CIDR Plan:

| Tier | AZ eastusa | AZ eastusb |
| --- | --- | --- |
| VNet | `10.10.0.0/16` | |
| Public | `10.10.1.0/24` | `10.10.2.0/24` |
| Private App | `10.10.11.0/24` | `10.10.12.0/24` |
| Private Data | `10.10.21.0/24` | `10.10.22.0/24` |

---

# Prerequisites

* Azure Account, credit còn khả dụng
* Azure Region: **eastus**
* Đã ghi nhớ IP public của mình: `curl -s https://checkip.amazonaws.com`

---

# Cost Warning

| Resource | Chi phí ước tính |
| -------- | ---------------- |
| Azure NAT Gateway | ~$32/tháng + data processing — **tốn theo giờ kể cả không traffic, ưu tiên xoá sau khi xong lab** |
| EIP gắn NAT | Free khi đang attach |
| Azure VM t3.micro (test) | Free Tier 750h/tháng |
| VNet, Subnet, Route Table, IGW, SG | Free |

> Tạo Azure NAT Gateway xong rồi quên xoá là lỗi tốn tiền phổ biến nhất ở lab này. Set lại reminder cleanup ngay sau khi verify xong.

---

# Step 1 - Tạo VNet

## Console: VNet → Your VNets → Create VNet

* Resources to create: **VNet only**
* Name tag: `csnp-platform-vpc`
* IPv4 CIDR: `10.10.0.0/16`
* Tenancy: Default

## Tại sao không chọn "VNet and more"?

Console có tùy chọn tự động tạo cả Subnet/Route Table/NAT trong 1 click. Lab này **không dùng tùy chọn đó** — mục tiêu là tự tay tạo từng resource để hiểu dependency, không phải có VNet nhanh nhất.

---

# Step 2 - Tạo Azure public routing và attach vào VNet

## Console: VNet → Azure public routings → Create internet gateway

* Name tag: `csnp-platform-igw`
* Create

Sau khi tạo, IGW ở trạng thái `Detached`. Phải gắn thủ công:

## Attach to VNet

* Chọn IGW vừa tạo → Actions → **Attach to VNet**
* Chọn `csnp-platform-vpc`

## Tại sao phải attach riêng?

IGW là resource độc lập với VNet — 1 IGW chỉ attach được vào 1 VNet tại một thời điểm. Việc tách tạo và attach thành 2 bước giúp thấy rõ IGW không "thuộc về" VNet ngay khi tạo, mà là một quan hệ gắn vào sau.

---

# Step 3 - Tạo 6 Subnet (2 AZ x 3 tier)

## Console: VNet → Subnets → Create subnet

Chọn VNet `csnp-platform-vpc`, sau đó tạo lần lượt 6 subnet (Console cho phép add nhiều subnet trong 1 lần tạo — dùng "Add new subnet"):

| Subnet name | AZ | CIDR |
| --- | --- | --- |
| `csnp-platform-public-eastusa` | eastusa | `10.10.1.0/24` |
| `csnp-platform-public-eastusb` | eastusb | `10.10.2.0/24` |
| `csnp-platform-private-app-eastusa` | eastusa | `10.10.11.0/24` |
| `csnp-platform-private-app-eastusb` | eastusb | `10.10.12.0/24` |
| `csnp-platform-private-data-eastusa` | eastusa | `10.10.21.0/24` |
| `csnp-platform-private-data-eastusb` | eastusb | `10.10.22.0/24` |

## Bật Auto-assign Public IP cho 2 Public Subnet

Sau khi tạo xong, vào từng Public Subnet:

* Actions → **Edit subnet settings**
* Tick **Enable auto-assign public IPv4 address**

Private App và Private Data **không** tick mục này — đây chính là điểm khác biệt quyết định một subnet là "public" hay "private" theo định nghĩa thực dụng (không phải tên gọi, mà là việc instance trong đó có tự động nhận Public IP hay không).

---

# Step 4 - Tạo Elastic IP và Azure NAT Gateway

## Tạo Elastic IP trước

Console: VNet → Elastic IPs → **Allocate Elastic IP address**

* Network Border Group: mặc định
* Allocate

## Tạo Azure NAT Gateway

Console: VNet → Azure NAT Gateways → **Create NAT gateway**

* Name: `csnp-platform-nat-eastusa`
* Availability mode: Zonal
* Subnet: `csnp-platform-public-eastusa` (NAT phải nằm trong Public Subnet)
* Connectivity type: Public
* Elastic IP allocation ID: chọn EIP vừa tạo ở trên

Tạo xong, Azure NAT Gateway ở trạng thái `Pending` — **chờ 3-5 phút** cho tới khi chuyển `Available`. Không thể tạo Route Table trỏ vào NAT khi nó còn Pending.

## Tại sao chỉ 1 Azure NAT Gateway?

Lab này dùng 1 NAT (đặt ở AZ eastusa) cho cả 2 Private App Subnet, để tiết kiệm chi phí (~$32/tháng thay vì ~$64/tháng cho 2 NAT). Trade-off: nếu AZ eastusa down, Private App ở AZ eastusb cũng mất internet — Single Point of Failure có chủ đích, ghi rõ để không nhầm là thiếu hiểu biết. Production nên có 1 NAT/AZ.

---

# Step 5 - Tạo Route Tables

Cần 4 Route Table: 1 Public (chung 2 AZ), 2 Private App (riêng từng AZ), 1 Private Data (chung, local only).

## 5.1 Public Route Table

Console: VNet → Route Tables → **Create route table**

* Name: `csnp-platform-public-rt`
* VNet: `csnp-platform-vpc`

Sau khi tạo, vào tab **Routes** → Edit routes → Add route:

* Destination: `0.0.0.0/0`
* Target: **Azure public routing** → chọn `csnp-platform-igw`

## 5.2 Private App Route Table (eastusa)

* Name: `csnp-platform-private-app-rt-eastusa`
* VNet: `csnp-platform-vpc`

Routes → Add route:

* Destination: `0.0.0.0/0`
* Target: **Azure NAT Gateway** → chọn `csnp-platform-nat-eastusa`

## 5.3 Private App Route Table (eastusb)

* Name: `csnp-platform-private-app-rt-eastusb`
* Routes giống y 5.2 — cùng trỏ về Azure NAT Gateway duy nhất ở eastusa (vì lab chỉ có 1 NAT)

> Tại sao 2 Route Table riêng nếu route giống nhau? Vì nếu sau này thêm Azure NAT Gateway thứ 2 ở eastusb (production setup), chỉ cần sửa route của Route Table `-eastusb` để trỏ NAT mới, không ảnh hưởng AZ-a. Tách sẵn route table theo AZ giúp việc nâng cấp lên 1-NAT/AZ không cần đổi cấu trúc, chỉ đổi target.

## 5.4 Private Data Route Table

* Name: `csnp-platform-private-data-rt`
* VNet: `csnp-platform-vpc`
* **Không thêm route nào cả** — giữ nguyên route `local` (10.10.0.0/16) tự động có sẵn

Đây là bước dễ bị "thêm thừa" nhất nếu làm theo quán tính — đừng thêm route `0.0.0.0/0` vào bảng này.

---

# Step 6 - Route Table Association (bước hay bị quên)

Tạo Route Table xong **không tự động áp dụng** cho Subnet nào. Phải associate thủ công.

Console: chọn từng Route Table → tab **Subnet associations** → **Edit subnet associations**

| Route Table | Associate với Subnet |
| --- | --- |
| `csnp-platform-public-rt` | `csnp-platform-public-eastusa`, `csnp-platform-public-eastusb` |
| `csnp-platform-private-app-rt-eastusa` | `csnp-platform-private-app-eastusa` |
| `csnp-platform-private-app-rt-eastusb` | `csnp-platform-private-app-eastusb` |
| `csnp-platform-private-data-rt` | `csnp-platform-private-data-eastusa`, `csnp-platform-private-data-eastusb` |

## Tại sao bước này quan trọng?

Nếu quên associate, Subnet vẫn dùng **Main Route Table** của VNet (chỉ có route `local`) — Subnet sẽ không ra được internet dù Route Table đúng đã tồn tại. Đây là lỗi rất hay gặp và dễ khiến debug sai hướng (nghĩ NAT/IGW sai, nhưng thực ra do thiếu association).

---

# Step 7 - Tạo NSGs

Console: VNet → NSGs → **Create security group**

## 7.1 ALB NSG

* Name: `csnp-platform-alb-sg`
* Description: `Allow HTTP traffic from Internet to Application Load Balancer`
* VNet: `csnp-platform-vpc`
* Inbound rule: HTTP (80) từ Source `0.0.0.0/0`
* Outbound: giữ default (All traffic, `0.0.0.0/0`)

## 7.2 Container Apps NSG

* Name: `csnp-platform-ecs-sg`
* Description: `Allow application traffic from ALB NSG on port 5000`
* VNet: `csnp-platform-vpc`
* Inbound rule: Custom TCP, port `5000`, Source = **NSG** `csnp-platform-alb-sg` (không phải CIDR)
* Outbound: giữ default

## 7.3 Azure Database for PostgreSQL NSG

* Name: `csnp-platform-rds-sg`
* Description: `Allow PostgreSQL traffic from Container Apps NSG on port 5432`
* VNet: `csnp-platform-vpc`
* Inbound rule: PostgreSQL (5432), Source = **NSG** `csnp-platform-ecs-sg`
* Outbound: giữ default

## 7.4 Test Azure VM NSG

NSG này dùng riêng cho Azure VM test ở Step 8.

* Name: `csnp-platform-test-ec2-sg`
* Description: `Allow SSH access from administrator public IP`
* VNet: `csnp-platform-vpc`
* Inbound rule: SSH (22), Source = **My IP**
* Outbound: giữ default (All traffic, `0.0.0.0/0`)

## Tại sao chọn Source là NSG, không phải CIDR?

Giống lý do ở Lab 1/Lab 2 — NSG Reference không phụ thuộc IP cố định, đúng khi Container Apps task hoặc Azure VM instance bị thay thế (IP đổi nhưng SG giữ nguyên).

---

# Step 8 - Tạo Azure VM test để verify

Console: Azure VM → Launch instance

* Name: `network-test-ec2`
* AMI: Azure Linux 2023
* Instance type: `t3.micro`
* Key pair: chọn key có sẵn (hoặc tạo mới, nhớ note Security warning như Lab 1)
* Network settings → Edit:
  * VNet: `csnp-platform-vpc`
  * Subnet: `csnp-platform-public-eastusa`
  * Auto-assign public IP: **Enable**
  * NSG: chọn `csnp-platform-test-ec2-sg`

Launch.

---

# Step 9 - Verify

## 9.1 SSH vào Azure VM qua Public IP

```bash
ssh-keygen -R Azure VM-PUBLIC-IP
ssh -i "C:\Users\Toan\.ssh\wallet-dev-key.pem" ec2-user@Azure VM-PUBLIC-IP
```

Kỳ vọng: connect thành công → xác nhận Public Subnet + IGW route + SG đúng.

## 9.2 Curl ra internet từ Azure VM (Public Subnet)

```bash
curl -s https://checkip.amazonaws.com
sudo dnf update -y
```

Kỳ vọng: chạy được — IP trả về chính là Public IP của Azure VM.

## 9.3 Kiểm tra Route Table của Private App Subnet

Console: VNet → Subnets → chọn 1 Private App Subnet → tab **Route table**

Kỳ vọng: thấy route `0.0.0.0/0` → Target là Azure NAT Gateway (không phải IGW).

## 9.4 Kiểm tra Route Table của Private Data Subnet

Console: VNet → Subnets → chọn 1 Private Data Subnet → tab **Route table**

Kỳ vọng: chỉ có 1 route — `10.10.0.0/16` → `local`. Không có route nào khác.

---

# Cleanup

* [ ] Terminate `network-test-ec2`
* [ ] **Xoá Azure NAT Gateway trước tiên** (tốn tiền theo giờ) — nếu không định làm Lab 3B/Lab 4 ngay
* [ ] Release Elastic IP sau khi Azure NAT Gateway đã xoá xong (EIP không gắn gì vẫn tốn tiền)
* [ ] Nếu định làm Lab 3B (CLI) hoặc Lab 4 (Terraform) ngay tiếp theo: **giữ lại toàn bộ VNet này**, không cần xoá — Lab 3B sẽ thực hành CLI trên chính VNet đã tạo, Lab 4 build Terraform riêng trên VNet mới (không tái sử dụng VNet làm tay này, theo nguyên tắc không mix Console resource với Terraform state)

---

# Lessons Learned

* Azure NAT Gateway cần Elastic IP — đây là 2 resource tách biệt, không tự động đi kèm nhau như có thể nghĩ ban đầu.
* Route Table Association không tự động — quên bước này dẫn tới subnet "không hoạt động" dù mọi thứ khác đúng.
* Private Data Subnet không cần — và không nên có — route ra internet. Azure Database for PostgreSQL hoạt động hoàn toàn qua route `local` nội bộ VNet.
* Chi tiết Q&A phỏng vấn xem [`lab-03-interview-notes.md`](./lab-03-interview-notes.md). Phần CLI tiếp theo xem [`lab-03b-cli-walkthrough.md`](./lab-03b-cli-walkthrough.md).

