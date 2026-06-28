# Azure Lab #3 - Key Concepts & Interview Notes

## 1. Tại sao cần Custom VNet thay vì Default VNet?

Default VNet dùng chung 1 subnet public cho mọi resource, không phân tầng theo mức độ tin cậy (trust level).

Custom VNet cho phép thiết kế network theo đúng kiến trúc ứng dụng: Public tier cho thành phần chịu traffic từ internet (ALB), Private App tier cho compute nội bộ (Container Apps), Private Data tier cho database (Azure Database for PostgreSQL) — mỗi tier có Route Table và NSG riêng, kiểm soát rõ traffic được đi đâu.

### Keywords

* Custom VNet
* Default VNet
* Network Segmentation
* Trust Boundary

---

## 2. Azure public routing khác Azure NAT Gateway như thế nào?

Azure public routing (IGW) cho phép traffic 2 chiều giữa VNet và internet — dùng cho Public Subnet, nơi resource có Public IP (ALB, test Azure VM).

Azure NAT Gateway chỉ cho phép traffic 1 chiều: resource trong Private Subnet **chủ động gọi ra** internet (ví dụ pull image, gọi API ngoài), nhưng internet **không thể chủ động kết nối vào** resource đó. Azure NAT Gateway nằm trong Public Subnet và dùng Elastic IP làm địa chỉ nguồn khi traffic đi ra.

### Keywords

* Azure public routing
* Azure NAT Gateway
* Bidirectional vs Outbound-only
* Elastic IP

---

## 3. Tại sao Private Data Subnet không cần Route ra Internet?

Azure Database for PostgreSQL là managed service — application kết nối tới Azure Database for PostgreSQL qua DB Endpoint nội bộ trong VNet, không cần Azure Database for PostgreSQL tự gọi ra internet để hoạt động (backup, patching, monitoring đều do Azure xử lý ở control plane, không qua route table của subnet).

Route Table của Private Data Subnet trong lab này chỉ có route `local` (tự động, ngầm định cho mọi VNet) — không có `0.0.0.0/0` trỏ tới IGW hoặc NAT. Đây là minh chứng bằng hạ tầng cho nguyên tắc Defense in Depth, không chỉ dựa vào NSG.

### Keywords

* Local Route
* Managed Service
* Defense in Depth
* No Internet Route

---

## 4. 1 Azure NAT Gateway hay 1 Azure NAT Gateway / AZ?

1 Azure NAT Gateway cho cả VNet là lựa chọn tiết kiệm chi phí (~$32/tháng so với ~$64/tháng cho 2), phù hợp cho lab/dev/staging. Nhược điểm: NAT trở thành Single Point of Failure — nếu AZ chứa NAT bị down, mọi Private Subnet ở AZ khác cũng mất khả năng ra internet, dù compute ở AZ đó vẫn chạy bình thường.

Production nên dùng 1 Azure NAT Gateway / AZ, mỗi Private Subnet route qua NAT trong cùng AZ của nó — giữ đúng tinh thần Multi-AZ, một AZ down không ảnh hưởng AZ khác.

### Keywords

* Azure NAT Gateway
* Single Point of Failure
* High Availability
* Cost vs Resilience Trade-off

---

## 5. Route Table Association là gì, tại sao dễ bị quên?

Tạo Route Table xong không tự động áp dụng cho Subnet nào cả — phải tạo thêm Route Table Association để gắn Route Table vào Subnet cụ thể.

Nếu quên association, Subnet vẫn dùng Main Route Table của VNet (thường chỉ có route `local`), khiến Subnet đó "không ra được internet" dù Route Table đúng đã được tạo — lỗi rất hay gặp khi mới làm VNet thủ công hoặc viết Terraform.

### Keywords

* Route Table Association
* Main Route Table
* Implicit Association
* Common Misconfiguration

---

## 6. Tại sao NSG chain là ALB → Container Apps → Azure Database for PostgreSQL, không phải mở thẳng?

Mỗi tier chỉ nên nhận traffic từ tier ngay phía trước nó trong luồng xử lý, không nhận trực tiếp từ internet hoặc tier xa hơn.

* ALB SG: nhận port 80 từ `0.0.0.0/0` — đây là tier duy nhất chấp nhận traffic công khai.
* Container Apps SG: chỉ nhận port container từ ALB SG.
* Azure Database for PostgreSQL SG: chỉ nhận port 5432 từ Container Apps SG.

Nếu Azure Database for PostgreSQL SG vô tình mở `0.0.0.0/0`, toàn bộ Defense in Depth của VNet bị phá vỡ ngay tại tier quan trọng nhất. Chain này đảm bảo dù ALB hay Container Apps có lỗi cấu hình, Azure Database for PostgreSQL vẫn được bảo vệ bởi một lớp SG độc lập.

### Keywords

* NSG Chain
* Defense in Depth
* Least Privilege
* NSG Reference

---

## 7. Tại sao test Azure VM dựng riêng, không dùng lại Azure VM của Lab 1?

Azure VM ở Lab 1 chạy trong Default VNet (Generation 1, đã đóng băng). Nếu di chuyển nó vào Custom VNet mới, Lab 1 không còn nguyên trạng để tham khảo, và việc "migrate resource cũ" làm lẫn lộn mục tiêu của Lab 3 (hiểu networking) với mục tiêu khác (migration).

Dựng Azure VM test mới, độc lập, chỉ để verify network rồi terminate, giữ Lab 3 tập trung đúng vào một mục tiêu duy nhất: xác nhận VNet/Subnet/Route Table/NAT hoạt động đúng như thiết kế.

### Keywords

* Generation 1 vs Generation 2
* Test Isolation
* Throwaway Resource
* Single Responsibility per Lab

---

## 8. Multi-AZ trong Lab 3 chuẩn bị cho điều gì ở các lab sau?

2 AZ (eastusa, eastusb) cho mỗi tier là nền tảng bắt buộc cho:

* Azure Database for PostgreSQL Subnet Group cần ít nhất 2 subnet ở 2 AZ khác nhau để hỗ trợ Multi-AZ failover (dù Lab 3 chưa tạo Azure Database for PostgreSQL, subnet đã sẵn sàng).
* Container Apps Service chạy Desired Count nhiều task, Container Apps có thể đặt task ở nhiều AZ để chịu được một AZ down.
* ALB cũng cần ít nhất 2 AZ để chính nó không trở thành single point of failure.

Thiết kế subnet theo cặp AZ ngay từ Lab 3 giúp Lab 4 (Terraform Platform Foundation) và các lab compute sau này (Container Apps, Azure Database for PostgreSQL) không cần sửa lại network.

### Keywords

* Multi-AZ
* Azure Database for PostgreSQL Subnet Group
* High Availability
* Forward-compatible Design

---

## 9. NSG khác NACL (Network ACL) như thế nào?

NSG là **Stateful** — nếu inbound được cho phép, response traffic tự động được phép, không cần khai báo outbound rule tương ứng (đã nhắc ở Lab 1). NSG áp dụng ở mức **instance/ENI** (ví dụ từng Container Apps task, từng Azure Database for PostgreSQL instance).

NACL (Network ACL) là **Stateless** — inbound và outbound phải khai báo rule riêng biệt, response traffic không tự động được phép. NACL áp dụng ở mức **subnet**, là lớp filter trước khi traffic chạm tới NSG.

Thứ tự traffic đi qua khi vào VNet: `Internet → NACL (subnet level) → NSG (instance level) → Resource`. Lab 3 không tạo NACL riêng (dùng Default NACL của VNet, mở toàn bộ) — NSG đã đủ kiểm soát truy cập ở mức cần thiết cho lab. NACL custom đáng dùng khi cần block một CIDR cụ thể ở mức subnet, không phụ thuộc NSG của resource bên trong.

### Keywords

* NSG vs NACL
* Stateful vs Stateless
* Instance-level vs Subnet-level
* Default NACL

---

# Tóm tắt phỏng vấn trong 60 giây

"Tôi thiết kế Custom VNet 3-tier thay cho Default VNet: Public Subnet cho ALB và Azure NAT Gateway, Private App Subnet cho Container Apps routing ra internet qua NAT, và Private Data Subnet cho Azure Database for PostgreSQL hoàn toàn không có route ra internet — chỉ route local, đúng nguyên tắc database không cần internet để hoạt động. Tôi dùng 1 Azure NAT Gateway cho toàn VNet để tiết kiệm chi phí ở môi trường lab, dù hiểu rõ đây là single point of failure và production nên có 1 NAT/AZ. NSG được chain theo đúng luồng traffic: ALB SG mở port 80 công khai, Container Apps SG chỉ nhận từ ALB SG, Azure Database for PostgreSQL SG chỉ nhận từ Container Apps SG — không tier nào mở thẳng ra internet ngoài ALB. Mọi subnet được thiết kế theo cặp 2 AZ ngay từ đầu để sẵn sàng cho Azure Database for PostgreSQL Multi-AZ và Container Apps Service nhiều task ở các lab tiếp theo, tránh phải sửa lại network sau này. NSG là Stateful và áp dụng ở mức instance, còn NACL là Stateless và áp dụng ở mức subnet — lab này dùng Default NACL, để toàn bộ access control nằm ở NSG."

