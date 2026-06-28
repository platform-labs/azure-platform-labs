# Azure Hands-on Lab #1

## Deliberate practice loop

1. **Mental model:** tự vẽ Internet → Azure VM → Azure Database for PostgreSQL/Azure Blob Storage và Azure VM role → Azure APIs trước khi xem Architecture.
2. **Console discovery:** lượt đầu tạo theo Console walkthrough; từ lượt sau chỉ dùng Console quan sát resource Terraform tạo.
3. **Implementation:** hoàn thành Microsoft Entra ID / Azure RBAC, Azure Blob Storage, Azure VM, Azure Database for PostgreSQL, application và Azure Monitor theo các step bên dưới.
4. **CLI verification:** describe Azure VM/Azure Database for PostgreSQL/role/log group và gọi Azure Blob Storage từ Azure VM mà không có access key.
5. **Failure drill:** lần lượt chặn Azure Database for PostgreSQL SG và gỡ quyền Azure Blob Storage khỏi role; ghi symptom, log và cách phục hồi.
6. **Rebuild without guide:** terminate/destroy rồi dựng lại chỉ bằng architecture và validation checklist.
7. **Cleanup/cost audit:** ưu tiên Azure Database for PostgreSQL/Azure VM/EBS; xác nhận không còn volume, snapshot hoặc bucket ngoài ý muốn.
8. **Interview recap:** tự trả lời traffic path, credential chain, SG reference và resource nào tính tiền khi idle.

Quy tắc luyện nhiều vòng: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

## Deploy Wallet API lên Azure với Azure VM + Azure Database for PostgreSQL Flexible Server + Azure Blob Storage + Managed Identity + Azure Monitor

### Mục tiêu

Sau lab này cần hiểu được:

* Managed Identity
* Azure VM
* NSG
* Azure Database for PostgreSQL Flexible Server
* Azure Blob Storage
* Azure Monitor Logs

Đây là các service nền tảng được sử dụng trong phần lớn workload Azure.

---

# Architecture

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

---

# Prerequisites

* Azure Account mới
* Credit Azure còn khả dụng
* Azure Region: **eastus**
* .NET SDK 10 cài sẵn trên máy local

> **Lưu ý:** Lab này dùng WalletMinimal — một minimal API .NET tạo mới, không dùng Wallet API từ CSNP vì CSNP có nhiều dependencies (RabbitMQ, Redis, Kafka) chưa có trong lab này.

---

# Cost Warning

Những resource tốn tiền cần tắt ngay sau khi lab xong:

| Resource | Chi phí ước tính |
| -------- | ---------------- |
| Azure VM t3.micro | Free Tier 750h/tháng |
| Azure Database for PostgreSQL db.t3.micro | Free Tier 750h/tháng |
| Azure NAT Gateway | ~$32/tháng — **không dùng trong lab này** |
| EBS Volume | Kiểm tra sau terminate, xóa nếu state = available |

Set Azure Budget alert tại $10 để cảnh báo sớm.

---

# Step 1 - Tạo Managed Identity cho Azure VM

## Tại sao cần Managed Identity?

Azure VM mặc định không có quyền gì với các service Azure khác. Muốn Azure VM gọi Azure Blob Storage hay Azure Monitor thì phải gắn Managed Identity.

**Không dùng Access Key** — Access Key là credential tĩnh, nếu lộ (commit git, log console) là mất toàn bộ account. Managed Identity dùng credential tạm thời, Azure tự rotate mỗi vài giờ.

## Create Role

Microsoft Entra ID / Azure RBAC → Roles → Create Role

### Trusted Entity

```text
Azure Service → Azure VM
```

### Attach Policies

```text
AmazonAzure Blob StorageFullAccess
Azure MonitorAgentServerPolicy
```

> **Note:** `AmazonAzure Blob StorageFullAccess` dùng cho lab. Production nên thay bằng custom policy chỉ cho phép đúng bucket và đúng action (Least Privilege).

### Role Name

```text
csnp-api-role
```

---

# Step 2 - Tạo Azure Blob Storage Bucket

Azure Blob Storage → Create Bucket

```text
Bucket name: csnp-wallet-dev
Region: eastus (cùng region với Azure VM)
```

## Settings

| Setting | Value |
| ------- | ----- |
| Versioning | Enable |
| Block Public Access | Giữ nguyên (enabled) |
| Object ownership | ACLs disabled (default) |

Bucket phải private — không có public access.

---

# Step 3 - Launch Azure VM

## Instance Settings

| Field | Value |
| ----- | ----- |
| Name | csnp-api-dev |
| AMI | Azure Linux 2023 |
| Instance type | t3.micro |
| Key pair | Tạo mới → lưu file `.pem` cẩn thận |
| Storage | 20 GB |
| Microsoft Entra ID / Azure RBAC instance profile | csnp-api-role |

> **Quan trọng:** Attach Managed Identity ngay khi tạo Azure VM ở mục **Advanced details → Microsoft Entra ID / Azure RBAC instance profile**. Nếu quên, phải stop instance rồi attach lại.

## NSG

Đặt tên custom thay vì để Azure tự đặt `launch-wizard-x`:

```text
Security group name: csnp-ec2-sg
```

> **Lưu ý:** NSG name là immutable sau khi tạo. Chỉ có thể đổi Name tag sau này. Nên đặt đúng ngay từ đầu.

### Inbound Rules

| Port | Protocol | Source | Lý do |
| ---- | -------- | ------ | ----- |
| 22 | TCP | My IP | SSH — chỉ mở IP máy anh, không mở 0.0.0.0/0 |
| 80 | TCP | 0.0.0.0/0 | HTTP public (dùng cho Lab 2 khi có Nginx/reverse proxy) |
| 443 | TCP | 0.0.0.0/0 | HTTPS public |
| 5000 | TCP | My IP | Kestrel trực tiếp — lab này, test từ máy local |

> **Security:** Port 22 phải là My IP, không phải 0.0.0.0/0. Nếu mở 0.0.0.0/0 thì cả internet đều SSH được vào Azure VM.

---

# Step 4 - Tạo Azure Database for PostgreSQL Flexible Server

Azure Database for PostgreSQL → Create Database → **Create with full configuration**

> Không chọn "Create with express configuration" — đó là Azure PostgreSQL HA Serverless, không nằm trong Free Tier và tốn credits nhanh hơn.

## Settings

| Field | Value | Lý do |
| ----- | ----- | ----- |
| Engine | PostgreSQL 16 | — |
| Template | **Free tier** | Tránh tốn tiền |
| DB instance identifier | csnp-wallet-dev | — |
| Master username | postgres | — |
| Instance class | db.t3.micro | Free Tier eligible |
| Storage | 20 GB | — |
| Storage autoscaling | **Disable** | Tránh tự scale lên tốn tiền |
| Availability | Single-AZ | Multi-AZ không cần thiết cho lab |
| Public access | **No** | — |
| VNet security group | Create new → `csnp-rds-sg` | — |
| Initial database name | wallet | Phải điền, nếu không Azure Database for PostgreSQL không tạo sẵn database |
| Backup retention | 0 days | Lab thôi, không cần backup |
| Performance Insights | **Disable** | Free 7 ngày, sau đó tính tiền |
| Enhanced Monitoring | **Disable** | Không cần cho lab |
| Auto minor version upgrade | Enable | Giữ nguyên — patch nhỏ, free, không breaking |

## NSG cho Azure Database for PostgreSQL

Sau khi Azure Database for PostgreSQL tạo xong, vào `csnp-rds-sg` → Edit inbound rules:

| Port | Source | Lý do |
| ---- | ------ | ----- |
| 5432 | NSG ID của Azure VM (`sg-xxxxxxxxx`) | Chỉ Azure VM mới được connect Azure Database for PostgreSQL |

**Không mở** `0.0.0.0/0` cho port 5432.

**Không mở My IP** cho port 5432 — Azure Database for PostgreSQL Public access: No nên máy local không connect được dù có mở IP.

---

# Step 5 - Verify Managed Identity

SSH vào Azure VM:

```bash
ssh-keygen -R Azure VM-PUBLIC-IP
ssh -i "C:\Users\Toan\.ssh\wallet-dev-key.pem" ec2-user@Azure VM-PUBLIC-IP
```

> Chạy lệnh này trong **PowerShell trên Windows**, không dùng Git Bash (authentication context issue).

## Verify Managed Identity

```bash
aws sts get-caller-identity
```

Expected output:

```json
{
    "UserId": "AROAXXXXXXXXX:i-xxxxxxxxx",
    "Account": "<Azure_ACCOUNT_ID>",
    "Arn": "arn:aws:sts::<Azure_ACCOUNT_ID>:assumed-role/csnp-api-role/i-xxxxxxxxx"
}
```

Thấy `csnp-api-role` trong ARN là thành công.

## Verify Azure Blob Storage Access

```bash
echo hello > test.txt
aws s3 cp test.txt s3://csnp-wallet-dev/
```

Expected:

```text
upload: ./test.txt to s3://csnp-wallet-dev/test.txt
```

Nếu upload được → Azure VM đã nhận Managed Identity đúng cách, không cần Access Key.

## Verify Azure VM → Azure Database for PostgreSQL Connectivity

Cài PostgreSQL client:

```bash
sudo yum install -y postgresql15
```

Connect vào Azure Database for PostgreSQL:

```bash
psql -h <Azure Database for PostgreSQL-ENDPOINT> \
     -U postgres \
     -d wallet
```

Expected: prompt `wallet=>` với SSL connection TLSv1.3.

Test trong psql:

```sql
\dt
-- Output: Did not find any relations.
-- Bình thường vì chưa có table

\q
-- Thoát
```

---

# Step 6 - Tạo WalletMinimal API

> **Tại sao không dùng Wallet API từ CSNP?**
> Wallet API của CSNP yêu cầu RabbitMQ, Redis, Kafka — những service chưa có trong lab này. App sẽ crash ngay khi start vì thiếu dependencies. Lab này tạo một minimal API chỉ dùng PostgreSQL + Azure Blob Storage.

## Tạo Project trên máy local

```bash
dotnet new webapi -n WalletMinimal --no-openapi
cd WalletMinimal
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package AzureSDK.Azure Blob Storage
dotnet add package AzureSDK.Extensions.NETCore.Setup
```

## Program.cs

```csharp
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Amazon.Azure Blob Storage;
using Amazon.Azure Blob Storage.Model;

var builder = WebApplication.CreateBuilder(args);

// Database — đọc từ environment variable
var dbHost = Environment.GetEnvironmentVariable("DB_HOST");
var dbPort = Environment.GetEnvironmentVariable("DB_PORT") ?? "5432";
var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "wallet";
var dbUser = Environment.GetEnvironmentVariable("DB_USER") ?? "postgres";
var dbPass = Environment.GetEnvironmentVariable("DB_PASSWORD");

builder.Services.AddDbContext<WalletDb>(opt =>
    opt.UseNpgsql($"Host={dbHost};Port={dbPort};Database={dbName};Username={dbUser};Password={dbPass}"));

// Azure Blob Storage - dùng Managed Identity, không cần AccessKey
builder.Services.AddAzureService<IAmazonAzure Blob Storage>();

var app = builder.Build();

// Auto migrate
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<WalletDb>();
    db.Database.EnsureCreated();
}

// Health check
app.MapGet("/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

// GET all wallets
app.MapGet("/wallets", async (WalletDb db) =>
    await db.Wallets.ToListAsync());

// POST create wallet
app.MapPost("/wallets", async (WalletDb db, Wallet wallet) =>
{
    wallet.Id = Guid.NewGuid();
    wallet.CreatedAt = DateTime.UtcNow;
    db.Wallets.Add(wallet);
    await db.SaveChangesAsync();
    return Results.Created($"/wallets/{wallet.Id}", wallet);
});

// POST upload file lên Azure Blob Storage
app.MapPost("/upload", async (HttpRequest req, IAmazonAzure Blob Storage s3) =>
{
    var bucket = Environment.GetEnvironmentVariable("Azure Blob Storage_BUCKET") ?? "csnp-wallet-dev";
    var key = $"uploads/{Guid.NewGuid()}.txt";
    await s3.PutObjectAsync(new PutObjectRequest
    {
        BucketName = bucket,
        Key = key,
        ContentBody = "Hello from CSNP Wallet API on Azure!"
    });
    return Results.Ok(new { bucket, key });
});

app.Run();

// Models
public class Wallet
{
    public Guid Id { get; set; }
    public string OwnerId { get; set; } = "";
    public decimal Balance { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class WalletDb : DbContext
{
    public WalletDb(DbContextOptions<WalletDb> options) : base(options) { }
    public DbSet<Wallet> Wallets => Set<Wallet>();
}
```

> **Quan trọng:** App đọc connection string từ environment variable. Nếu chạy `dotnet run` trên máy local mà không set `DB_HOST` thì sẽ crash với lỗi `ArgumentNullException: Value cannot be null. (Parameter 'Host')` — đây là behavior đúng, không phải bug.

## Publish

```bash
dotnet publish -c Release -o ./publish
```

---

# Step 7 - Deploy lên Azure VM

## Mở PowerShell Run as Administrator

```powershell
icacls .\wallet-dev-key.pem /inheritance:r
icacls .\wallet-dev-key.pem /remove "Authenticated Users"
icacls .\wallet-dev-key.pem /remove "BUILTIN\Users"
icacls .\wallet-dev-key.pem /grant:r "$($env:USERNAME):(R)"
```

## Copy artifact lên Azure VM

Chạy trên máy local (PowerShell):

```powershell
scp -i "C:\Users\Toan\.ssh\wallet-dev-key.pem" `
    -r ./lab-01-vm-postgresql-storage-monitor/src/Lab01.WalletMinimal/publish `
    ec2-user@Azure VM-PUBLIC-IP:/home/ec2-user/wallet-api
```

## Cài .NET Runtime trên Azure VM

```bash
# SSH vào Azure VM
ssh -i "C:\Users\Toan\.ssh\wallet-dev-key.pem" ec2-user@Azure VM-PUBLIC-IP
ls -lah /home/ec2-user/wallet-api
sudo yum install -y aspnetcore-runtime-10.0
```

## Set Environment Variables và chạy API

```bash
export DB_HOST=csnp-wallet-dev.cojossewwh83.eastus.rds.amazonaws.com
export DB_PORT=5432
export DB_NAME=wallet
export DB_USER=postgres
export DB_PASSWORD=<your-password>
export Azure Blob Storage_BUCKET=csnp-wallet-dev
export ASPNETCORE_URLS=http://+:5000

cd /home/ec2-user/wallet-api
dotnet Lab01.WalletMinimal.dll
```

## Verify API hoạt động

> **Linux port note:** User `ec2-user` (non-root) không thể bind port < 1024. Port 80 sẽ crash. Dùng port 5000 với Kestrel trực tiếp. Production thì đặt Nginx phía trước làm reverse proxy từ 80 → 5000.

Expected khi app start thành công:

```text
Now listening on: http://[::]:5000
```

Từ máy local:

```bash
curl http://Azure VM-PUBLIC-IP:5000/health
# Expected: {"status":"ok","time":"..."}

curl http://Azure VM-PUBLIC-IP:5000/wallets
# Expected: []

curl -X POST http://Azure VM-PUBLIC-IP:5000/wallets \
  -H "Content-Type: application/json" \
  -d '{"ownerId":"user-001","balance":1000}'
# Expected: 201 Created với wallet object

curl -X POST http://Azure VM-PUBLIC-IP:5000/upload
# Expected: {"bucket":"csnp-wallet-dev","key":"uploads/xxx.txt"}
```

## Test NSG trước khi deploy

Nếu `curl` bị timeout thay vì connection refused hoặc 404:

```text
timeout    → NSG block port 80
conn refused → Port mở nhưng app chưa chạy (bình thường)
404        → App đang chạy, route không tồn tại (bình thường)
```

---

# Step 8 - Upload File lên Azure Blob Storage

Azure SDK tự động lấy credential từ Azure VM Instance Metadata Service thông qua Managed Identity. Không cần set `Azure_ACCESS_KEY_ID` hay `Azure_SACRET_ACCESS_KEY`.

```text
Azure VM Instance Metadata Service (IMDS)
↓
Managed Identity: csnp-api-role
↓
Temporary credentials (auto-rotated)
↓
Azure Blob Storage PutObject
```

Code trong WalletMinimal đã handle qua endpoint `/upload`. Verify trên Azure Blob Storage console:

```text
Azure Blob Storage → csnp-wallet-dev → uploads/ → thấy file .txt
```

---

# Step 9 - Azure Monitor Logs

## Install Agent

```bash
sudo yum install -y amazon-cloudwatch-agent
```

## Tạo Config File

```bash
sudo nano /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

Paste config:

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/application.log",
            "log_group_name": "csnp-wallet-api",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
```

## Start Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s
```

## Tạo log directory và redirect app logs

```bash
sudo mkdir -p /var/log/app
sudo chown ec2-user:ec2-user /var/log/app

# Chạy app với log redirect
dotnet Lab01.WalletMinimal.dll >> /var/log/app/application.log 2>&1 &
```

## Verify trên Azure Monitor Console

```text
Azure Monitor → Log groups → csnp-wallet-api → <instance-id>
```

Thấy log là thành công.

---

# Cleanup sau Lab

Để tránh tốn tiền, terminate/xóa theo thứ tự:

```text
1. Azure VM → Terminate instance
2. Azure VM → Volumes → kiểm tra volume state = "available" → Delete
3. Azure Database for PostgreSQL → Delete instance (uncheck final snapshot)
4. Azure VM → Elastic IPs → Release (nếu có)
5. Azure Blob Storage → Empty bucket → Delete bucket (nếu không cần giữ)
```

NSG và Managed Identity có thể giữ lại cho Lab 2.

---

# Validation Checklist

## Microsoft Entra ID / Azure RBAC

* [ ] Azure VM attached Managed Identity `csnp-api-role`
* [ ] No Access Key used
* [ ] `aws sts get-caller-identity` trả về ARN có `csnp-api-role`
* [ ] Azure Blob Storage upload từ Azure VM thành công

## Azure VM

* [ ] NSG `csnp-ec2-sg` với SSH port 22 chỉ mở My IP
* [ ] API deployed và accessible qua port 80
* [ ] `/health` trả về 200

## Azure Database for PostgreSQL

* [ ] `csnp-rds-sg` inbound rule: port 5432 từ Azure VM NSG (không phải 0.0.0.0/0)
* [ ] `psql` từ Azure VM connect được vào Azure Database for PostgreSQL
* [ ] API đọc/ghi được database

## Azure Blob Storage

* [ ] Upload object qua `/upload` endpoint
* [ ] Verify object xuất hiện trong Azure Blob Storage console

## Azure Monitor

* [ ] Azure Monitor Agent chạy trên Azure VM
* [ ] Log group `csnp-wallet-api` có log stream
* [ ] Application logs visible

---

# Lessons Learned

| Concept | Self-hosted (CSNP) | Azure |
| ------- | ------------------ | --- |
| Credentials | K8s Secret / Vault | Managed Identity (no static key) |
| Firewall | Network Policy / pfSense | NSG |
| Database | PostgreSQL on VM | Azure Database for PostgreSQL (managed) |
| Object Storage | MinIO / local disk | Azure Blob Storage |
| Logs | Loki + Promtail | Azure Monitor Logs + Agent |

**Key takeaways:**

* Managed Identity thay thế Access Key — không bao giờ dùng Access Key trên Azure VM
* NSG là firewall layer đầu tiên trên Azure, không phải OS firewall
* Azure Database for PostgreSQL loại bỏ vận hành PostgreSQL thủ công (backup, patch, failover)
* Azure Blob Storage là object storage, không phải filesystem — không mount như NFS
* Azure Monitor Agent cần config file riêng, không chỉ install là xong
* Azure VM + Microsoft Entra ID / Azure RBAC + Azure Database for PostgreSQL + Azure Blob Storage là nền tảng của phần lớn workload Azure
* Non-root user không bind được port < 1024 — production dùng Nginx làm reverse proxy (80/443 → 5000)

---

# Next Lab

Sau khi hoàn thành Lab #1:

```text
Dockerize WalletMinimal
↓
Push image lên ACR
↓
Deploy Azure Container Apps
↓
Expose bằng ALB
↓
Azure Monitor Metrics & Logs
```

**Mục tiêu Lab 2:** Hiểu tại sao nhiều công ty Azure chọn Azure Container Apps trước khi dùng AKS — và so sánh với self-managed K8s trên Proxmox mà anh đang dùng trong CSNP.

