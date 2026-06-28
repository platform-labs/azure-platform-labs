# Azure Platform Labs - Volume 1: Foundation (Lab 0.5 → Lab 3B) Interview Question Bank

> Tài liệu ôn tập theo dạng **câu hỏi phỏng vấn + câu trả lời chuẩn + ghi nhớ production**.
>
> Phạm vi: Lab 0.5 Cost Guardrail, Lab 1 Azure VM+Azure Database for PostgreSQL+Azure Blob Storage+Microsoft Entra ID / Azure RBAC+Azure Monitor, Lab 2 Docker+ACR+Azure Container Apps+ALB, Lab 3A VNet Console, Lab 3B VNet CLI.

---

# LAB 0.5 - Cost Guardrail

## 1. Vì sao phải set Budget Alert trước khi học Azure?

**Trả lời chuẩn:**
Nhiều dịch vụ Azure (Azure Database for PostgreSQL, Azure NAT Gateway, Azure PostgreSQL HA, Azure Event Hubs Kafka endpoint, Azure Front Door/CDN) tính phí theo giờ hoặc theo traffic ngay cả khi gần như không dùng. Nếu quên tắt resource, bill có thể tăng nhanh trong vài ngày. Budget Alert là lưới an toàn tối thiểu trước khi bắt đầu thực hành.

**Ghi nhớ:**
Cost Guardrail không phải optimization, mà là phòng ngừa rủi ro tài chính cá nhân.

---

## 2. Phân biệt Azure Budget và Cost Explorer?

**Trả lời chuẩn:**
Azure Budget là cơ chế cảnh báo chủ động (proactive) — set ngưỡng, Azure gửi email khi vượt. Cost Explorer là công cụ phân tích thụ động (reactive) — xem chi tiêu đã phát sinh, breakdown theo service/tag. Budget để phòng ngừa, Cost Explorer để điều tra sau khi đã phát sinh chi phí.

**Ghi nhớ:**
Budget = cảnh báo trước. Cost Explorer = soi sau.

---

## 3. Ngưỡng Warning $5 / Critical $10 dựa trên nguyên tắc gì?

**Trả lời chuẩn:**
Đây là ngưỡng nhỏ phù hợp với learning lab quy mô cá nhân, không phải production. Warning giúp phát hiện sớm khi có resource chạy ngoài dự kiến (ví dụ quên tắt Azure NAT Gateway), Critical là điểm cần dừng ngay và kiểm tra toàn bộ resource đang chạy.

**Ghi nhớ:**
Ngưỡng phải tỷ lệ với rủi ro thực tế của môi trường, không copy số production.

---

## 4. Dịch vụ nào dễ "đốt tiền âm thầm" nhất trong các lab?

**Trả lời chuẩn:**
Azure NAT Gateway (tính phí theo giờ + theo GB xử lý) và Azure Database for PostgreSQL/Azure PostgreSQL HA (tính phí theo giờ instance đang chạy) là hai nguồn tốn tiền âm thầm phổ biến nhất, vì chúng vẫn tính phí dù không có traffic. Azure MQ/Azure Event Hubs Kafka endpoint và Azure Front Door/CDN cũng cần theo dõi khi bật lên cho lab nâng cao.

**Ghi nhớ:**
Bất cứ resource nào billing theo giờ (NAT, Azure Database for PostgreSQL, Azure PostgreSQL HA) đều phải có quy trình tắt rõ ràng sau mỗi session học.

---

# LAB 1 - Azure VM + Azure Database for PostgreSQL + Azure Blob Storage + Microsoft Entra ID / Azure RBAC + Azure Monitor

## 5. Azure VM Instance Role khác gì so với việc nhúng Access Key vào code?

**Trả lời chuẩn:**
Microsoft Entra ID / Azure RBAC Instance Role gắn credential tạm thời (temporary, tự động xoay vòng) vào Azure VM thông qua Instance Metadata Service, không cần lưu Access Key/Secret Key tĩnh trong code hay file config. Access Key tĩnh là rủi ro bảo mật lớn vì dễ bị leak qua Git, log, hoặc image.

**Ghi nhớ:**
Không bao giờ hardcode Access Key trên Azure VM chạy production — luôn dùng Instance Role.

---

## 6. NSG khác Network ACL như thế nào?

**Trả lời chuẩn:**
NSG hoạt động ở cấp instance/ENI, là stateful (traffic trả về tự động được phép), chỉ có rule "Allow". Network ACL hoạt động ở cấp subnet, là stateless (phải khai báo rule cho cả inbound và outbound), hỗ trợ cả "Allow" và "Deny".

**Ghi nhớ:**
SG = tường bảo vệ instance, stateful. NACL = tường bảo vệ subnet, stateless, có thể deny rõ ràng.

---

## 7. Vì sao Azure Database for PostgreSQL nên đặt ở Private Subnet?

**Trả lời chuẩn:**
Database chứa dữ liệu nhạy cảm, không cần và không nên expose trực tiếp ra Internet. Đặt Azure Database for PostgreSQL ở Private Subnet (không có route tới Azure public routing) đảm bảo chỉ resource trong VNet (như Azure VM/Container Apps ở Private App Subnet) mới truy cập được, qua NSG kiểm soát chặt.

**Ghi nhớ:**
Database production luôn ở Private Subnet, không có public IP, không route qua IGW.

---

## 8. Azure Blob Storage Bucket Policy khác Microsoft Entra ID / Azure RBAC Policy như thế nào?

**Trả lời chuẩn:**
Microsoft Entra ID / Azure RBAC Policy gắn vào identity (user/role) và xác định identity đó được làm gì. Bucket Policy gắn vào resource (chính cái bucket) và xác định ai được truy cập bucket đó, kể cả cross-account. Khi cần, Azure đánh giá kết hợp (Allow phải có ít nhất một bên cho phép, Deny ở bất kỳ bên nào sẽ chặn).

**Ghi nhớ:**
Microsoft Entra ID / Azure RBAC Policy = "identity được làm gì". Bucket Policy = "ai được vào resource này".

---

## 9. Azure Monitor Metrics vs Azure Monitor Logs khác nhau ra sao?

**Trả lời chuẩn:**
Metrics là dữ liệu số theo thời gian (CPU%, RequestCount, MemoryUtilization) dùng để vẽ dashboard và set alarm. Logs là dữ liệu văn bản chi tiết (application log, access log) dùng để debug nguyên nhân cụ thể. Metrics trả lời "có vấn đề không", Logs trả lời "vấn đề là gì".

**Ghi nhớ:**
Alarm dựa trên Metrics. Root cause analysis dựa trên Logs.

---

## 10. Vì sao nên tách Azure VM Role ra theo least privilege, không gán AdministratorAccess?

**Trả lời chuẩn:**
AdministratorAccess cho phép làm mọi thứ trên toàn account, nếu instance bị compromise (qua lỗ hổng app) thì attacker có toàn quyền Azure. Least privilege giới hạn role chỉ có quyền cần thiết (ví dụ chỉ đọc/viết một bucket Azure Blob Storage cụ thể), giảm blast radius khi xảy ra sự cố.

**Ghi nhớ:**
Mọi Role production phải scope theo least privilege, không bao giờ dùng AdministratorAccess cho service role.

---

## 11. Elastic IP khác Public IP thường của Azure VM như thế nào?

**Trả lời chuẩn:**
Public IP thường gán tự động khi launch và đổi mỗi khi stop/start instance. Elastic IP là IP tĩnh do mình giữ, không đổi qua các lần restart, và có thể remap sang instance khác nhanh khi cần failover. Elastic IP không dùng vẫn bị tính phí nhẹ.

**Ghi nhớ:**
Public IP tự động = tạm, đổi liên tục. Elastic IP = cố định, dùng cho endpoint cần ổn định.

---

## 12. Khi nào nên dùng Azure Database for PostgreSQL Multi-AZ ngay từ Lab 1?

**Trả lời chuẩn:**
Lab 1 ở mức học tập, dùng Single-AZ để tiết kiệm chi phí và đơn giản hóa mental model trước. Multi-AZ chỉ cần khi đã hiểu rõ failover hoạt động ra sao và khi chuẩn bị production thật (xem ở Lab 9 Azure PostgreSQL HA). Học không nên nhảy thẳng vào HA phức tạp khi chưa nắm nền tảng.

**Ghi nhớ:**
Single-AZ cho học/dev, Multi-AZ cho production cần uptime.

---

# LAB 2 - Docker + ACR + Azure Container Apps + ALB

## 13. Azure Container Apps khác Container Apps trên Azure VM (Azure VM launch type) như thế nào?

**Trả lời chuẩn:**
Container Apps là serverless compute cho container — Azure tự quản lý Azure VM instance phía sau, mình chỉ định CPU/Memory cho task. Azure VM launch type yêu cầu mình tự quản lý Azure VM instance (patch OS, scale capacity, đặt Auto Scaling Group) làm host cho container.

**Ghi nhớ:**
Container Apps = không quản lý server. Azure VM launch type = vẫn phải quản lý server, đổi lại rẻ hơn ở scale lớn và kiểm soát sâu hơn.

---

## 14. Task Role và Execution Role khác nhau ở điểm nào?

**Trả lời chuẩn:**
Execution Role được Container Apps Agent dùng để pull image từ ACR và gửi log lên Azure Monitor — đây là quyền hạ tầng, không liên quan logic app. Task Role được chính application bên trong container dùng để gọi Azure API (như đọc Azure Blob Storage, gọi Azure Blob lease locking) — đây là quyền nghiệp vụ app cần.

**Ghi nhớ:**
Execution Role = quyền cho Container Apps vận hành container. Task Role = quyền cho code app bên trong container.

---

## 15. Vì sao ALB Health Check quan trọng với self-healing?

**Trả lời chuẩn:**
ALB liên tục gọi health check endpoint của từng Target. Nếu Task không trả 200 sau số lần thử quy định, ALB đánh dấu unhealthy và ngừng gửi traffic tới đó. Container Apps Service phát hiện Task unhealthy (qua health check hoặc container exit) và tự khởi tạo Task mới để duy trì desired count — đó là self-healing.

**Ghi nhớ:**
Health Check là cơ chế phát hiện lỗi. Desired Count + Container Apps Service là cơ chế tự phục hồi.

---

## 16. Target Group dùng để làm gì giữa ALB và Container Apps?

**Trả lời chuẩn:**
Target Group là tập hợp các đích (Task IP + port) mà ALB sẽ phân phối traffic tới, kèm cấu hình health check riêng. ALB Listener route request tới Target Group dựa trên rule (path, host header), và Target Group theo dõi sức khỏe từng Task để quyết định route traffic vào đâu.

**Ghi nhớ:**
ALB quyết định route theo rule, Target Group là nơi thực sự theo dõi và chứa danh sách Task khỏe mạnh.

---

## 17. Vì sao Docker Image cần build multi-stage?

**Trả lời chuẩn:**
Multi-stage build tách giai đoạn build (cần SDK, compiler, dependency nặng) ra khỏi giai đoạn runtime (chỉ cần runtime nhẹ). Kết quả là image cuối cùng nhỏ hơn nhiều, giảm thời gian pull, giảm attack surface vì không mang theo build tool không cần thiết.

**Ghi nhớ:**
Multi-stage build = nhỏ hơn, an toàn hơn, deploy nhanh hơn.

---

## 18. ACR Repository Policy dùng để giải quyết vấn đề gì?

**Trả lời chuẩn:**
ACR Repository Policy kiểm soát ai (account, role, service) được pull/push image của một repository cụ thể, tương tự Bucket Policy của Azure Blob Storage nhưng cho image registry. Cần khi muốn cho phép cross-account pull hoặc giới hạn chỉ CI/CD role mới được push.

**Ghi nhớ:**
ACR Policy = kiểm soát truy cập image, không phải kiểm soát nội dung image.

---

## 19. Rolling Update của Container Apps Service hoạt động ra sao?

**Trả lời chuẩn:**
Container Apps tạo Task mới với revision Task Definition mới, chờ Task mới pass health check rồi mới bắt đầu drain traffic và tắt Task cũ, theo tỷ lệ `minimumHealthyPercent`/`maximumPercent` đã cấu hình. Mục tiêu là không có downtime trong lúc deploy.

**Ghi nhớ:**
Rolling update giữ traffic luôn có Task khỏe mạnh phục vụ, không tắt hết cũ trước khi mới sẵn sàng.

---

## 20. Tại sao nên dùng default VNet ở Lab 2 trước khi vào Custom VNet ở Lab 5?

**Trả lời chuẩn:**
Lab 2 tập trung học container/ALB/Container Apps, chưa cần thêm độ phức tạp networking. Dùng default VNet giúp cô lập biến số học tập — học đúng một khái niệm mỗi lần (triết lý deliberate practice của roadmap), tránh nhảy Terraform/Custom VNet quá sớm trước khi hiểu rõ resource cơ bản.

**Ghi nhớ:**
Mỗi lab nên giới hạn biến số mới để học sâu, không học nhiều khái niệm cùng lúc.

---

# LAB 3A - Custom VNet Networking (Console)

## 21. Vì sao chia subnet thành 3 tier: Public, Private App, Private Data?

**Trả lời chuẩn:**
Đây là mô hình network segmentation theo trust boundary: Public Subnet chứa resource cần expose Internet (ALB, Azure NAT Gateway); Private App Subnet chứa compute logic nghiệp vụ (Container Apps/Azure VM), không expose trực tiếp; Private Data Subnet chứa database, tier nhạy cảm nhất, cách Internet xa nhất. Mỗi tier giới hạn blast radius nếu tier ngoài bị compromise.

**Ghi nhớ:**
3-tier = giảm attack surface theo nguyên tắc defense in depth.

---

## 22. Azure public routing (IGW) khác Azure NAT Gateway như thế nào?

**Trả lời chuẩn:**
IGW cho phép traffic hai chiều giữa VNet và Internet, dùng cho resource có public IP (như ALB, bastion host). Azure NAT Gateway chỉ cho phép traffic một chiều — resource ở Private Subnet chủ động ra Internet (ví dụ pull update, gọi API ngoài) nhưng Internet không thể chủ động kết nối vào.

**Ghi nhớ:**
IGW = hai chiều, dùng cho Public Subnet. NAT = một chiều (outbound only), dùng cho Private Subnet.

---

## 23. Vì sao mỗi Private Subnet cần Route Table riêng trỏ tới Azure NAT Gateway ở đúng AZ?

**Trả lời chuẩn:**
Azure NAT Gateway nằm trong một AZ cụ thể. Nếu Private Subnet ở AZ khác trỏ qua Azure NAT Gateway ở AZ kia, traffic phải đi cross-AZ, tăng latency và phụ thuộc vào một AZ — nếu AZ đó down, toàn bộ outbound traffic của Private Subnet khác cũng bị ảnh hưởng. Best practice là mỗi AZ có Azure NAT Gateway riêng và Route Table riêng trỏ đúng AZ đó.

**Ghi nhớ:**
1 Azure NAT Gateway / AZ + Route Table riêng theo AZ = tránh single point of failure cross-AZ.

---

## 24. Route Table Association dùng để làm gì?

**Trả lời chuẩn:**
Route Table Association gắn một Route Table cụ thể với một Subnet cụ thể, xác định subnet đó sẽ dùng route nào để định tuyến traffic ra ngoài (qua IGW, NAT, hay chỉ local). Không có association, subnet dùng Main Route Table mặc định của VNet.

**Ghi nhớ:**
Route Table định nghĩa "đường đi". Association quyết định "subnet nào dùng đường nào".

---

## 25. CIDR `10.10.1.0/24` và `10.10.2.0/24` có bị overlap không? Vì sao chia 2 subnet Public ở 2 AZ?

**Trả lời chuẩn:**
Không overlap vì `/24` cho mỗi subnet chỉ chiếm đúng 256 địa chỉ trong dải riêng (`10.10.1.x` và `10.10.2.x`), không giao nhau. Chia 2 Public Subnet ở 2 AZ khác nhau để đạt High Availability — nếu một AZ down, ALB/NAT ở AZ còn lại vẫn hoạt động.

**Ghi nhớ:**
Mỗi tier cần ít nhất 2 subnet ở 2 AZ khác nhau để có HA, không chỉ vì compliance mà vì khả năng chịu lỗi thật.

---

## 26. Trust Boundary là gì và áp dụng vào VNet 3-tier như thế nào?

**Trả lời chuẩn:**
Trust Boundary là ranh giới phân định mức độ tin cậy giữa các vùng hệ thống. Trong VNet 3-tier, Public Subnet là vùng ít tin cậy nhất (tiếp xúc trực tiếp Internet), Private App là vùng tin cậy trung bình (chỉ nhận traffic từ ALB qua NSG), Private Data là vùng tin cậy cao nhất (chỉ nhận traffic từ Private App). Mỗi lần traffic vượt boundary phải qua kiểm soát rõ ràng (SG, NACL).

**Ghi nhớ:**
Trust Boundary giúp trả lời "traffic này có nên đi qua đây không", không chỉ "traffic này có đi qua được không".

---

# LAB 3B - VNet Networking (CLI)

## 27. Vì sao học CLI sau khi đã làm Console ở Lab 3A?

**Trả lời chuẩn:**
Theo triết lý roadmap (Console → CLI → Terraform → Production Design → Platform Engineering), Console giúp hình thành mental model trực quan về resource và quan hệ giữa chúng trước. CLI sau đó lộ ra chính xác Azure API nằm phía sau mỗi click trên Console, giúp hiểu sâu hơn input/output của từng resource trước khi tự động hóa bằng Terraform.

**Ghi nhớ:**
Không nhảy thẳng vào automation khi chưa hiểu rõ resource bằng tay.

---

## 28. Resource Dependency là gì, ví dụ trong việc tạo VNet bằng CLI?

**Trả lời chuẩn:**
Resource Dependency là quan hệ resource A phải tồn tại trước khi resource B có thể được tạo. Ví dụ: phải `create-vpc` trước khi `create-subnet` (subnet cần `vpc-id`), phải có subnet và route table trước khi `associate-route-table`, và Azure public routing phải `attach` vào VNet trước khi route table có thể trỏ route `0.0.0.0/0` qua nó.

**Ghi nhớ:**
CLI buộc mình nhìn rõ thứ tự dependency mà Console có thể che giấu bằng UI tiện lợi.

---

## 29. Vì sao thứ tự xóa resource (destroy order) lại quan trọng và phải ngược với thứ tự tạo?

**Trả lời chuẩn:**
Azure sẽ từ chối xóa resource nếu vẫn còn resource khác phụ thuộc vào nó (ví dụ không thể xóa VNet khi subnet bên trong vẫn còn, hoặc không thể detach/delete IGW khi route table vẫn còn route trỏ tới nó). Vì vậy destroy order luôn ngược với create order: xóa resource con trước, resource cha sau.

**Ghi nhớ:**
Create: cha trước con sau. Destroy: con trước cha sau.

---

## 30. Sandbox CIDR `10.20.0.0/16` (Lab 3B) khác CIDR `10.10.0.0/16` (Lab 3A) để làm gì?

**Trả lời chuẩn:**
Lab 3B là sandbox throwaway, dùng CIDR khác hẳn để tránh nhầm lẫn hoặc overlap nếu cả hai VNet cùng tồn tại song song trong account khi đang học. Việc tách CIDR rõ ràng giúp dễ nhận diện resource nào thuộc lab nào khi debug hoặc cleanup.

**Ghi nhớ:**
Đặt CIDR khác nhau cho mỗi VNet học tập giúp tránh nhầm lẫn và an toàn khi cleanup song song.

---

## 31. `create-route-table` và `associate-route-table` là hai bước tách biệt, vì sao?

**Trả lời chuẩn:**
Tạo Route Table chỉ định nghĩa tập hợp route (đường đi), chưa gắn với subnet cụ thể nào. Associate là bước riêng để chỉ định route table đó áp dụng cho subnet nào. Tách hai bước cho phép một Route Table được dùng lại (associate) cho nhiều subnet cùng lúc nếu cần.

**Ghi nhớ:**
Tạo route table = định nghĩa luật. Associate = áp luật đó vào đối tượng cụ thể.

---

## 32. Khi `delete-vpc` báo lỗi "DependencyViolation", cần kiểm tra gì trước?

**Trả lời chuẩn:**
Lỗi này nghĩa là vẫn còn resource con phụ thuộc VNet chưa xóa hết — thường là: Subnet còn tồn tại, Azure public routing chưa detach, Azure NAT Gateway chưa delete, NSG khác default chưa xóa, hoặc ENI (network interface) còn gắn vào resource khác. Cần xóa/detach theo đúng thứ tự ngược trước khi xóa VNet.

**Ghi nhớ:**
"DependencyViolation" luôn là dấu hiệu thiếu một bước cleanup con, không phải lỗi của lệnh xóa VNet.

