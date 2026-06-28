# Lab 03A - Custom VNet Networking (Console)

## Mục tiêu

Generation 1 (Lab 1, Lab 2) chạy trên **default VNet** — đủ để học Azure VM/Azure Database for PostgreSQL/Azure Blob Storage/Container Apps/ALB ở mức resource riêng lẻ, nhưng không phản ánh đúng cách một fintech platform thật nên đặt network. Lab 3A xây **custom VNet 3-tier bằng Azure Console**, làm tay từng bước — đúng triết lý học `UI → CLI → Terraform` đã dùng ở Lab 1 và Lab 2. Phần CLI để dành cho **Lab 3B (VNet Networking CLI)**, phần Terraform để dành cho **Lab 4 (Platform Foundation)**, build trên VNet mới, không tái sử dụng VNet làm tay ở đây.

Sau lab này cần hiểu được:

* Custom VNet, Subnet theo tier (public / private-app / private-data)
* Azure public routing vs Azure NAT Gateway — khi nào cần cái nào, và dependency giữa chúng (EIP → NAT → Route Table)
* Route Table theo tier, vì sao Data tier không cần route ra internet
* Route Table Association — bước hay bị quên, hiểu rõ vì đã tự tay làm
* NSG chain: Internet → ALB SG → Container Apps SG → Azure Database for PostgreSQL SG
* Multi-AZ làm nền cho High Availability (Azure Database for PostgreSQL subnet group, Container Apps service sau này)
* Console và CLI gọi cùng API nào — chuẩn bị trực giác cho Terraform ở Lab 4

**Lab 1 và Lab 2 không bị động tới** — coi như "Generation 1", đóng băng nguyên trạng trên default VNet.

## Nội dung Lab 3A

| Phần | Nội dung | File |
| --- | --- | --- |
| Hands-on | Làm tay qua Console — full VNet 3-tier, NAT, Route Table, SG, verify | [`docs/lab-03a-hands-on.md`](./docs/lab-03a-hands-on.md) |
| Verification | Checklist kiểm tra network hoạt động đúng | [`docs/lab-03-verification.md`](./docs/lab-03-verification.md) |
| Interview Notes | Q&A phỏng vấn, keyword theo từng concept | [`docs/lab-03-interview-notes.md`](./docs/lab-03-interview-notes.md) |

**Liên quan:**
* Lab 3B (Azure CLI) — thư mục riêng: [`../lab-03b-vnet-networking-cli/`](../lab-03b-vnet-networking-cli/)
* Lab 4 (Terraform) — thư mục riêng: [`../lab-04-terraform-platform-foundation/`](../lab-04-terraform-platform-foundation/)

## Prerequisites

* Azure Account, credit còn khả dụng
* Azure Region: **eastus**
* Azure CLI đã configure (cho phần 3B)
* Một Azure VM key pair đã có sẵn (dùng tạm cho test Azure VM)

## Architecture

Sơ đồ dưới đây mô tả **traffic flow logical** (luồng request đi qua các tier theo nghiệp vụ, qua NSG) — **không phải** route table thật giữa các subnet. Mỗi tier có route table riêng, độc lập, xem bảng Route Table bên dưới.

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
                 |                                    |
                 |   - Azure NAT Gateway (in 1a only)       |
                 |   - network-test-ec2 (temporary)   |
                 |   - ALB sẽ vào đây ở Lab 4+         |
                 +----------------------------------+
                                  |
                    (traffic logic: ALB -> Container Apps SG)
                                  v
                 +----------------------------------+
                 |       Private App Subnet          |
                 |   10.10.11.0/24 (eastusa)      |
                 |   10.10.12.0/24 (eastusb)      |
                 |   - Container Apps tasks sẽ vào đây ở Lab 4+   |
                 +----------------------------------+
                                  |
                    (traffic logic: Container Apps -> Azure Database for PostgreSQL SG)
                                  v
                 +----------------------------------+
                 |       Private Data Subnet         |
                 |   10.10.21.0/24 (eastusa)      |
                 |   10.10.22.0/24 (eastusb)      |
                 |   - Azure Database for PostgreSQL sẽ vào đây ở Lab 4+         |
                 +----------------------------------+
```

Route table thật của từng tier (network layer, tách biệt với traffic flow ở trên):

| Tier | Default route (`0.0.0.0/0`) | Ghi chú |
| --- | --- | --- |
| Public | → Azure public routing | 2 chiều, có Public IP |
| Private App | → Azure NAT Gateway | 1 chiều ra ngoài, không có Public IP |
| Private Data | **Không có** | chỉ có route `local` (10.10.0.0/16), không ra internet được dù qua NAT hay IGW |

NSG chain:

```text
Internet → [ALB SG: port 80 from 0.0.0.0/0]
              ↓
         [Container Apps SG: port 5000 from ALB SG only]
              ↓
         [Azure Database for PostgreSQL SG: port 5432 from Container Apps SG only]
```

## CIDR Plan

| Tier | AZ eastusa | AZ eastusb |
| --- | --- | --- |
| VNet | `10.10.0.0/16` | |
| Public | `10.10.1.0/24` | `10.10.2.0/24` |
| Private App | `10.10.11.0/24` | `10.10.12.0/24` |
| Private Data | `10.10.21.0/24` | `10.10.22.0/24` |

> **Phân biệt 2 CIDR dùng trong Lab 3:**
> * `10.10.0.0/16` — **Source of truth**, VNet chính làm tay ở Lab 3A, đã verify, giữ nguyên để Lab 4 tham khảo/so sánh.
> * `10.20.0.0/16` — **CLI Learning Sandbox**, dùng riêng ở Lab 3B, throwaway, tạo và xoá tự do để học dependency mà không sợ phá VNet chính.

## Azure NAT Gateway Trade-off

Lab dùng **1 Azure NAT Gateway** (đặt ở Public Subnet AZ-a), cả 2 Private App subnet đều route qua nó.

* Chi phí thấp hơn (~$32/tháng so với ~$64/tháng cho 2 NAT)
* Trade-off: NAT là Single Point of Failure — nếu AZ-a down, Private App ở AZ-b mất internet
* Production nên dùng **1 Azure NAT Gateway / AZ** để giữ đúng tinh thần Multi-AZ

## Azure Services

| Service | Vai trò |
| ------- | ------- |
| VNet | `csnp-platform-vpc`, CIDR `10.10.0.0/16` |
| Azure public routing | Cho Public Subnet ra internet |
| Azure NAT Gateway | 1 cái, đặt ở Public Subnet AZ-a, cho Private App ra internet |
| Route Tables | Public RT (→ IGW), Private App RT x2 theo AZ (→ NAT), Private Data RT (local only) |
| NSGs | ALB SG, Container Apps SG, Azure Database for PostgreSQL SG, test Azure VM SG |
| Azure VM (test) | `network-test-ec2`, t3.micro, tạm thời, chỉ để verify network |

## Estimated Cost

| Resource | Chi phí ước tính |
| -------- | ----------------- |
| Azure NAT Gateway | ~$32/tháng + data processing — **chạy theo giờ kể cả không traffic, ưu tiên xoá sau khi xong lab nếu nghỉ dài** |
| EIP (gắn vào NAT) | Free khi đang attach, tốn tiền nếu để rảnh (unattached) |
| Azure VM t3.micro (test) | Free Tier 750h/tháng |
| VNet, Subnet, Route Table, NSG, IGW | Free |

## Region

`eastus`

## Cleanup

* [ ] Terminate `network-test-ec2` ngay sau khi verify xong
* [ ] **Xoá Azure NAT Gateway trước tiên** (tốn tiền theo giờ) nếu không định làm Lab 3B/Lab 4 ngay
* [ ] Release Elastic IP sau khi NAT đã xoá
* [ ] Nếu định làm Lab 3B hoặc Lab 4 tiếp ngay: **giữ lại VNet này** — Lab 3B thực hành CLI trên VNet test riêng (không đụng VNet chính), Lab 4 build Terraform trên VNet hoàn toàn mới (không tái sử dụng VNet làm tay)

## Lessons Learned

* Data tier (Azure Database for PostgreSQL) không cần route ra internet để hoạt động — managed service connect qua endpoint nội bộ. Tách hẳn route table cho tier này là cách rõ ràng nhất để chứng minh bằng hạ tầng, không chỉ bằng NSG.
* 1 Azure NAT Gateway là lựa chọn hợp lý cho lab/dev, nhưng là Single Point of Failure theo AZ — trade-off có ý thức, không phải thiếu hiểu biết.
* Route Table Association là thứ hay bị quên khi làm tay — tạo Route Table xong mà không associate với Subnet thì Subnet vẫn dùng Main Route Table (chỉ có route local), dễ gây nhầm "tại sao subnet này không ra được internet".
* Console và CLI gọi cùng API Azure — khác biệt là Console tự lưu context và tự chặn xoá khi còn dependency.
* Chi tiết đầy đủ + Q&A phỏng vấn xem [`docs/lab-03-interview-notes.md`](./docs/lab-03-interview-notes.md).

## Trạng thái

Làm tay qua Console trước ([`lab-03a-hands-on.md`](./docs/lab-03a-hands-on.md)), sau đó một phần qua CLI ([`lab-03b-cli-walkthrough.md`](./docs/lab-03b-cli-walkthrough.md)) trên VNet test riêng để không ảnh hưởng VNet chính. Terraform hoá toàn bộ network này — trên VNet mới, không tái sử dụng — là phạm vi của `lab-04-terraform-platform-foundation/`.

