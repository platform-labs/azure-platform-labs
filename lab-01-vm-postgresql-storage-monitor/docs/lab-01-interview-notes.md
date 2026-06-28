# Azure Lab #1 - Key Concepts & Interview Notes

## 1. Tại sao phải dùng Managed Identity?

Managed Identity cung cấp danh tính (Identity) và quyền (Permissions) cho Azure VM.

Azure sẽ tự cấp Temporary Credentials thông qua Instance Metadata Service (IMDS), giúp application truy cập các Azure Services như Azure Blob Storage, Azure Monitor, Azure Blob lease locking... mà không cần lưu Access Key trong source code, file config hoặc CI/CD pipeline.

### Keywords

* Identity
* Permissions
* IMDS (Instance Metadata Service)
* Temporary Credentials

---

## 2. Tại sao không dùng Access Key?

Access Key là Static Credential.

Nếu bị lộ qua Git, log, CI/CD hoặc máy developer thì attacker có thể sử dụng ngay các quyền được cấp cho Access Key đó.

Managed Identity sử dụng Temporary Credentials được Azure tự động rotate định kỳ nên an toàn hơn, đồng thời không cần quản lý secret thủ công.

### Keywords

* Static Credential
* Temporary Credential
* Credential Rotation
* Least Privilege

---

## 3. Tại sao Azure Database for PostgreSQL Public Access = No?

Database không nên expose trực tiếp ra Internet.

Azure Database for PostgreSQL nên nằm trong private network và chỉ cho phép application server truy cập.

Việc giới hạn network exposure giúp giảm Attack Surface và tuân thủ nguyên tắc Defense in Depth.

### Keywords

* Private Network
* Private Subnet
* Attack Surface
* Defense in Depth

---

## 4. Tại sao NSG của Azure Database for PostgreSQL chỉ cho Azure VM NSG truy cập?

Thay vì mở theo IP Address, NSG của Azure Database for PostgreSQL chỉ cho phép NSG của Azure VM kết nối.

Điều này đảm bảo chỉ các Azure VM thuộc nhóm ứng dụng mới có thể truy cập database, kể cả khi IP của Azure VM thay đổi.

### Keywords

* NSG Reference
* Application Tier
* Network Isolation

---

## 5. Azure Monitor Agent làm gì?

Azure Monitor Agent thu thập Logs, Metrics và System Information từ Azure VM rồi gửi lên Azure Monitor.

Trong Lab #1, Agent đọc file:

/var/log/app/application.log

và gửi dữ liệu lên Azure Monitor Logs để phục vụ:

* Monitoring
* Troubleshooting
* Centralized Logging
* Observability

### Keywords

* Centralized Logging
* Metrics Collection
* Observability
* Troubleshooting

---

# Tóm tắt phỏng vấn trong 30 giây

"Tôi sử dụng Managed Identity thay vì Access Key để tránh lưu Static Credentials trên Azure VM. Azure Database for PostgreSQL được cấu hình Private Access và chỉ cho phép NSG của Azure VM truy cập nhằm giảm Attack Surface. Azure Monitor Agent được dùng để thu thập Logs và Metrics từ Azure VM, sau đó gửi lên Azure Monitor phục vụ Monitoring và Troubleshooting tập trung."

---

## 6. Azure VM lấy Credentials từ đâu?

Khi Azure VM được attach Managed Identity, application không cần Access Key.

Azure VM sẽ gọi Instance Metadata Service (IMDS) để lấy Temporary Credentials do Azure cấp.

Azure tự động rotate các credentials này định kỳ nên không cần quản lý secret thủ công.

### Keywords

* IMDS (Instance Metadata Service)
* Temporary Credentials
* Credential Rotation
* Managed Identity

---

## 7. Microsoft Entra ID / Azure RBAC User khác Managed Identity như thế nào?

Microsoft Entra ID / Azure RBAC User là danh tính cố định, thường đi kèm Access Key hoặc Password.

Managed Identity là danh tính tạm thời có thể được Assume bởi Azure Services, Users hoặc Applications.

Trong production, Azure VM nên sử dụng Managed Identity thay vì Microsoft Entra ID / Azure RBAC User.

### Keywords

* Microsoft Entra ID / Azure RBAC User
* Managed Identity
* Assume Role
* Temporary Credentials
* Static Credentials

---

## 8. NSG là Stateful hay Stateless?

NSG là Stateful Firewall.

Nếu inbound request được cho phép thì response traffic sẽ tự động được cho phép mà không cần cấu hình outbound rule tương ứng.

Điều này giúp quản lý firewall đơn giản hơn.

### Keywords

* Stateful Firewall
* Inbound Rules
* Outbound Rules
* Connection Tracking

---

## 9. NSG Reference là gì?

Thay vì mở port theo IP Address, NSG có thể cho phép traffic từ một NSG khác.

Trong Lab #1, Azure Database for PostgreSQL chỉ cho phép NSG của Azure VM truy cập PostgreSQL port 5432.

Cách này an toàn hơn và không bị ảnh hưởng khi IP của Azure VM thay đổi.

### Keywords

* NSG Reference
* Dynamic Membership
* Network Isolation
* Application Tier

---

## 10. Tại sao dùng Azure Database for PostgreSQL thay vì PostgreSQL trên Azure VM?

Azure Database for PostgreSQL là Managed Database Service.

Azure chịu trách nhiệm cho nhiều tác vụ vận hành như:

* Backup
* Monitoring
* Minor Version Upgrade
* Patching
* Failover (khi sử dụng Multi-AZ)

Developer tập trung vào application thay vì quản trị database server.

### Keywords

* Managed Service
* Backup
* Patching
* Monitoring
* Operational Overhead

---

## 11. Có SSH vào Azure Database for PostgreSQL được không?

Không.

Azure Database for PostgreSQL không cung cấp SSH Access như Azure VM.

Application hoặc Database Client chỉ có thể kết nối thông qua Database Endpoint và Protocol tương ứng.

Ví dụ:

* PostgreSQL → Port 5432
* MySQL → Port 3306

### Keywords

* Managed Database
* Database Endpoint
* PostgreSQL Protocol
* No SSH Access

---

## 12. Azure Blob Storage là File System hay Object Storage?

Azure Blob Storage là Object Storage.

Mỗi object bao gồm:

* Data
* Metadata
* Key

Azure Blob Storage không phải là File System truyền thống và không được thiết kế để mount như NFS hoặc SMB.

### Keywords

* Object Storage
* Bucket
* Object
* Metadata
* Key

---

## 13. Tại sao không lưu file upload trên Azure VM?

Azure VM là Compute Resource có thể bị terminate hoặc thay thế bất kỳ lúc nào.

Nếu file chỉ tồn tại trên Azure VM thì dữ liệu có thể mất khi instance bị xóa hoặc scale lại.

Azure Blob Storage được thiết kế cho việc lưu trữ lâu dài với độ bền và tính sẵn sàng rất cao.

### Keywords

* Durable Storage
* Ephemeral Compute
* High Availability
* Object Storage

---

## 14. Tại sao phải đẩy Logs lên Azure Monitor?

Nếu logs chỉ tồn tại trên Azure VM:

```text
/var/log/app/application.log
```

thì khi Azure VM bị terminate, logs sẽ mất theo.

Azure Monitor giúp tập trung logs từ nhiều instance về một nơi để phục vụ:

* Monitoring
* Troubleshooting
* Auditing
* Incident Investigation

### Keywords

* Centralized Logging
* Monitoring
* Troubleshooting
* Audit Trail
* Observability

---

## 15. Tại sao Application chạy port 5000 thay vì 80?

Trên Linux, các port nhỏ hơn 1024 là Privileged Ports.

User thông thường như ec2-user không được phép bind trực tiếp vào các port này.

Thông thường application sẽ chạy ở port 5000 và sử dụng Reverse Proxy như Nginx hoặc Load Balancer để expose ra port 80 hoặc 443.

### Keywords

* Privileged Ports
* Reverse Proxy
* Nginx
* Kestrel
* Port Binding

---

## 16. Request Flow từ Internet đến Database

Khi user gửi request:

```text
Internet
    ↓
NSG
    ↓
Azure VM
    ↓
Wallet API
    ↓
Azure Database for PostgreSQL Flexible Server
    ↓
Response
```

Nếu upload file:

```text
Internet
    ↓
Wallet API
    ↓
Managed Identity
    ↓
Azure Blob Storage
```

Nếu ghi logs:

```text
Wallet API
    ↓
application.log
    ↓
Azure Monitor Agent
    ↓
Azure Monitor Logs
```

### Keywords

* Request Flow
* Data Flow
* Application Tier
* Database Tier
* Observability Flow

---

# Tóm tắt phỏng vấn trong 60 giây

"Tôi triển khai Wallet API trên Azure VM và sử dụng Managed Identity để Azure VM lấy Temporary Credentials từ Instance Metadata Service thay vì dùng Access Key. Database PostgreSQL chạy trên Azure Database for PostgreSQL với Public Access tắt và chỉ cho phép NSG của Azure VM truy cập nhằm giảm Attack Surface. Dữ liệu file được lưu trên Azure Blob Storage thay vì Azure VM vì Azure Blob Storage là Object Storage có độ bền cao hơn. Application logs được thu thập bởi Azure Monitor Agent và gửi lên Azure Monitor Logs để phục vụ Monitoring và Troubleshooting tập trung. Toàn bộ request flow đi từ Internet → NSG → Azure VM → Application → Azure Database for PostgreSQL hoặc Azure Blob Storage tùy nghiệp vụ."

