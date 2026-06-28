# Lab 03 - Custom VNet Networking

## Mục tiêu

Generation 1 (Lab 1, Lab 2) chạy trên **default VNet** — đủ để học Azure VM/Azure Database for PostgreSQL/Azure Blob Storage/Container Apps/ALB ở mức resource riêng lẻ, nhưng không phản ánh đúng cách một fintech platform thật nên đặt network. Lab này xây **custom VNet 3-tier**, là nền tảng để Lab 4 viết lại Lab 1 bằng Terraform đúng chuẩn — không phải hack thêm VNet vào Terraform cũ.

Sau lab này cần hiểu được:

* Custom VNet, Subnet theo tier (public / private-app / private-data)
* Azure public routing vs Azure NAT Gateway — khi nào cần cái nào
* Route Table theo tier, vì sao Data tier không cần route ra internet
* NSG chain: Internet → ALB SG → Container Apps SG → Azure Database for PostgreSQL SG
* Multi-AZ làm nền cho High Availability (Azure Database for PostgreSQL subnet group, Container Apps service sau này)

**Lab 1 và Lab 2 không bị động tới** — coi như "Generation 1", đóng băng nguyên trạng trên default VNet.

## Prerequisites

* Azure Account, credit còn khả dụng
* Azure Region: **eastus**
* Terraform >= 1.5.0
* Một Azure VM key pair đã có sẵn (dùng tạm cho test Azure VM, xoá key pair sau khi xong nếu không cần nữa)

## Architecture

Lưu ý: sơ đồ dưới đây mô tả **traffic flow logical** (luồng request đi qua các tier theo nghiệp vụ, qua NSG). Đây **không phải** route table thật giữa các subnet — mỗi tier có route table riêng, độc lập, xem chi tiết ở bảng Route Table bên dưới sơ đồ.

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

Route table thật của từng tier (đây là network layer, tách biệt với traffic flow ở trên):

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
| Azure NAT Gateway | 1 cái, đặt ở Public Subnet AZ-a, cho Private App ra internet (apt update, pull image...) |
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

* [ ] Terminate `network-test-ec2` ngay sau khi verify xong (không cần giữ)
* [ ] Nếu nghỉ dài hạn: xoá Azure NAT Gateway trước (tốn tiền theo giờ), giữ lại VNet/Subnet/Route Table/SG (free)
* [ ] `terraform destroy` nếu muốn dẹp toàn bộ — nhưng nếu định làm Lab 4 ngay tiếp theo, **giữ lại VNet này**, Lab 4 sẽ build trên cùng VNet
* [ ] Kiểm tra EIP không còn ở trạng thái unattached sau destroy

## Verification Checklist

Xem chi tiết lệnh ở [`docs/lab-03-verification.md`](./docs/lab-03-verification.md). Tóm tắt:

* [ ] SSH vào `network-test-ec2` qua Public IP — thành công
* [ ] Từ `network-test-ec2`, `curl` ra internet — thành công (đi qua IGW)
* [ ] Từ một instance trong Private App Subnet, `curl`/`apt update` ra internet — thành công (đi qua NAT, không có Public IP)
* [ ] Private Data Subnet — route table xác nhận KHÔNG có route `0.0.0.0/0`
* [ ] Azure Database for PostgreSQL (khi tạo ở Lab 4) — xác nhận `publicly_accessible = false` và chỉ SG của Container Apps mới gọi được port 5432

## Lessons Learned

* Data tier (Azure Database for PostgreSQL) không cần route ra internet để hoạt động — managed service connect qua endpoint nội bộ, không cần gọi ra ngoài. Tách hẳn route table cho tier này là cách rõ ràng nhất để chứng minh điều đó bằng hạ tầng, không phải chỉ bằng NSG.
* 1 Azure NAT Gateway là lựa chọn hợp lý cho lab/dev, nhưng là Single Point of Failure theo AZ — cần nhớ đây là trade-off có ý thức, không phải thiếu hiểu biết.
* Route Table Association là thứ hay bị quên — tạo Route Table xong mà không associate với Subnet thì Subnet vẫn dùng Main Route Table của VNet (thường chỉ có route local), dễ gây nhầm "tại sao subnet này không ra được internet".
* Chi tiết đầy đủ + Q&A phỏng vấn xem [`docs/lab-03-interview-notes.md`](./docs/lab-03-interview-notes.md).

## Trạng thái

Viết bằng Terraform ngay từ đầu (không làm tay qua Console trước) — khác Lab 1/Lab 2. Lý do: VNet networking có nhiều resource phụ thuộc nhau (subnet → route table → association → NAT → EIP), làm tay qua Console dễ rối thứ tự hơn so với Azure VM/Azure Database for PostgreSQL/Azure Blob Storage đơn lẻ. Điền `terraform.tfvars` (copy từ `.example`), xác nhận `my_ip_cidr` và `key_pair_name` trước khi `terraform apply`.

