# Azure Platform Learning Roadmap (CSNP Edition) — Final

## Mục tiêu

Roadmap này nhằm:

* Pass Azure AZ-104
* Xây nền tảng Azure vững chắc
* Hiểu bản chất hạ tầng Azure
* Chuẩn bị đưa CSNP lên Azure production
* Phát triển theo hướng Senior Platform Engineer

> Azure track này giữ triết lý học của AWS track, nhưng không phải bản
> search/replace AWS sang Azure. Khi Azure không có managed equivalent 1:1,
> roadmap phải nói rõ trade-off và chọn dịch vụ Azure-native.

---

# Triết lý học

```text
Console
↓
CLI
↓
Terraform
↓
Production Design
↓
Platform Engineering
```

Không nhảy Terraform quá sớm. Phải hiểu resource trước khi IaC hóa.

Từ Lab 4 trở đi, Console được dùng để discovery và quan sát resource do IaC tạo, không bắt buộc dựng thêm một stack thủ công giống hệt. Mọi lab dùng deliberate-practice loop: mental model → Console discovery → implementation → CLI verification → failure drill → rebuild không nhìn guide → cleanup/cost audit → interview recap. Xem `DELIBERATE_PRACTICE.md` và `PRACTICE_MATRIX.md`.

---

# PHASE 0 — COST GUARDRAIL

## Lab 0.5 — Azure Cost Guardrail

### Mục tiêu

Tránh bill bất ngờ khi bắt đầu dùng các dịch vụ có thể tốn tiền (Azure Database for PostgreSQL, Azure NAT Gateway, Azure PostgreSQL HA, Azure Event Hubs Kafka endpoint...).

### Thực hành

* Tạo Azure Budget
* Cost Alert
* Email Notification

### Ngưỡng đề xuất

```text
Warning:  $5
Critical: $10
```

### Áp dụng đặc biệt cho

* Lab 1 (Azure Database for PostgreSQL)
* Lab 3A/3B (Azure NAT Gateway)
* Lab 9 (Azure PostgreSQL HA)
* Lab 12A/12B (Azure MQ / Azure Event Hubs Kafka endpoint)
* Lab 15 (Azure Front Door/CDN)

### Học được

* Cost Awareness
* Cost Control
* Azure Billing Basics

---

# PHASE 1 — FOUNDATION

## Lab 1 — Azure VM + Azure Database for PostgreSQL + Azure Blob Storage + Microsoft Entra ID / Azure RBAC + Azure Monitor

### Mục tiêu

Làm quen các dịch vụ Azure cốt lõi.

### Nội dung

* Azure VM
* Azure Database for PostgreSQL Flexible Server
* Azure Blob Storage
* Microsoft Entra ID / Azure RBAC Instance Role
* Azure Monitor

### Thực hành

Deploy WalletMinimal:

```text
Azure VM
↓
Azure Database for PostgreSQL
↓
Azure Blob Storage
```

### Học được

* Compute
* Database
* Object Storage
* Managed Identity
* NSG

---

## Lab 2 — Docker + ACR + Azure Container Apps

### Mục tiêu

Container hóa ứng dụng.

### Nội dung

* Docker
* ACR
* Azure Container Apps
* Container Apps Environment
* Container App
* Ingress
* Revision
* Managed Identity

### Thực hành

Deploy WalletMinimal:

```text
Container Apps ingress
 ↓
Container App revision
 ↓
Azure Database for PostgreSQL
```

### Học được

* Container
* Orchestration
* Azure-native ingress
* Self Healing
* Managed Identity vs platform-managed image pull

---

# PHASE 2 — NETWORKING

## Lab 3A — Custom VNet Networking (Console)

### Source of Truth

CIDR:

```text
10.10.0.0/16
```

### Mục tiêu

Tự tay xây VNet bằng Azure Console.

### Nội dung

* VNet
* Azure public routing
* Azure NAT Gateway
* Public IP
* Route Tables
* Route Associations

### Subnets

Public:

```text
10.10.1.0/24
10.10.2.0/24
```

Private App:

```text
10.10.11.0/24
10.10.12.0/24
```

Private Data:

```text
10.10.21.0/24
10.10.22.0/24
```

### Học được

* Public vs Private
* Routing
* NAT Gateway vs public ingress/Public IP
* Trust Boundary

---

## Lab 3B — VNet Networking (CLI)

### Learning Sandbox

CIDR:

```text
10.20.0.0/16
```

### Mục tiêu

Hiểu Azure API phía sau Console.

### Nội dung

* `az network vnet create`
* `az network vnet subnet create`
* `az network route-table create`
* `az network nsg create`
* `az network nat gateway create`
* delete resources in dependency order

### Học được

* Resource dependency
* Create order
* Destroy order

---

# PHASE 3 — INFRASTRUCTURE AS CODE

## Lab 4 — Terraform Platform Foundation (Network Only)

### Prerequisites

* Lab 3A
* Lab 3B

### Mục tiêu

Terraform hóa network layer (VNet 3-tier) — **scope đã chốt: chỉ network, không bao gồm Azure VM/Azure Database for PostgreSQL/Azure Blob Storage/Microsoft Entra ID / Azure RBAC/Azure Monitor**. Các resource đó thuộc về app stack, được Terraform hoá trong Lab 5 (xem lý do ở mục Lab 5 bên dưới).

### Terraform Resources

* VNet
* Subnets (Public / Private App / Private Data)
* Azure NAT Gateway
* Route Tables
* NSGs for ingress, app, and data tiers

### Học được

* Terraform State
* Dependency Graph
* IaC

### Trạng thái

**Done.**

---

## Lab 5 — Terraform Container Apps Platform (= Terraform hoá Lab 2, đặt vào Custom VNet + Azure Database for PostgreSQL/Azure Blob Storage/Managed Identity)

### Mục tiêu

Lab 5 chính là **bản Terraform của Lab 2** (Dockerize → ACR → Azure Container Apps), nhưng đặt đúng vào Custom VNet 3-tier (output từ Lab 4) thay vì default VNet, và tách rõ platform identity với application Managed Identity.

Vì Lab 5 đóng vai "Terraform hoá toàn bộ app stack" (không chỉ Container Apps), nên **Azure Database for PostgreSQL, Azure Blob Storage, Managed Identity cũng thuộc Lab 5** — không phải Lab 4. Lab 4 chỉ cung cấp network layer dùng chung (VNet/Subnet/NSG); mọi resource phục vụ trực tiếp cho app (database, storage, app permissions) đi theo app stack ở Lab 5.

### Prerequisites

* Lab 4 (network only — `vnet_id`, `private_app_subnet_ids`, `private_data_subnet_ids`, `ingress_nsg_id`, `app_nsg_id`, `data_nsg_id`)

### Terraform Resources

Container Apps:

* ACR
* Container Apps Environment
* Container App
* Ingress
* Revision

Database & Storage (chuyển từ Lab 4 sang đây):

* Azure Database for PostgreSQL Flexible Server (private data tier)
* Azure Blob Storage account/container

Microsoft Entra ID / Azure RBAC:

* Managed Identity cho application
* Azure RBAC scoped đúng resource app cần gọi

### Kiến trúc

```text
Container Apps ingress
 ↓
Container Apps (Private App)
 ↓
Azure Database for PostgreSQL (Private Data) — tạo bởi chính Lab 5
```

### Học được

* Production Container Apps Architecture
* Terraform Modules
* Container Apps Deployment
* Vì sao network (Lab 4) và app stack (Lab 5) nên tách lab riêng — network ít đổi, app stack đổi liên tục theo service

### Trạng thái

Code đã viết (`rds.tf` mới thêm, `variables.tf`/`ecs.tf`/outputs đã update để dùng `azure_db_instance.wallet_db.address` thay vì `var.db_host` cứng). **Chưa `terraform apply`** — cần làm tiếp.

---

# PHASE 4 — OPERATIONS

## Lab 6 — Observability

### Nội dung

* Azure Monitor Dashboard
* Metrics
* Logs
* Alarms
* Container Insights

### Security

* Key Vault
* Key Vault keys

### Học được

* Monitoring
* Alerting
* Secret Management

---

## Lab 7 — Auto Scaling & Resilience

### Nội dung

* Container Apps Auto Scaling
* CPU Scaling
* Memory Scaling
* Replica count
* Min Count
* Max Count

### HA Concepts

* Multi-AZ
* Health Checks
* Self Healing

### Học được

* Resilience
* Scaling

---

## Lab 8 — CI/CD

### Nội dung

GitHub Actions:

* Build
* Test
* Docker Build
* Push ACR
* Deploy Container Apps

### Pipeline

```text
Git Push
 ↓
GitHub Actions
 ↓
ACR
 ↓
Container Apps
```

### Học được

* Continuous Delivery
* Deployment Automation

---

# PHASE 5 — ARCHITECTURE

## Lab 9 — Azure Database for PostgreSQL HA

### Nội dung

* Azure Database for PostgreSQL HA
* Read Replica
* Multi-AZ
* Failover

### So sánh

```text
Azure Database for PostgreSQL Flexible Server
vs
Azure Database for PostgreSQL HA
```

### Học được

* Database HA
* Managed Database Scaling

---

## Lab 9.5 — Container Apps vs AKS Architecture Decision

### Output bắt buộc

ADR:

```text
ADR-XXXX-Container Apps-VS-AKS.md
```

### Nội dung

* Container Apps
* AKS
* Cost
* Operations
* Complexity
* Migration Strategy

### Case Study

CSNP:

```text
Why Container Apps today?
When AKS tomorrow?
```

### Học được

* Architecture Decision Records
* Trade-off Analysis

---

## Lab 10 — AKS

### Nội dung

* AKS Cluster
* Deployment
* Service
* Ingress
* HPA

### Mapping

```text
Container Apps Environment → AKS Cluster
Container App              → Deployment/Pod
Container Apps Ingress     → Ingress + Service
Scale rule                 → HPA/KEDA
```

### Học được

* Kubernetes trên Azure

---

# PHASE 6 — CSNP PRODUCTION SERVICES

## Lab 11 — Azure Cache for Redis

### Nội dung

* Redis
* Cache
* Distributed Lock
* Session
* Rate Limiting

### Học được

* Caching Strategy

---

## Lab 12A — Azure Service Bus Messaging

### Priority

**Required**

### Nội dung

* Azure Service Bus
* Queue
* Topic / Subscription
* MassTransit
* Retry
* DLQ

### Liên hệ CSNP

```text
Wallet
Payment
Ledger
Notification
```

### Học được

* Azure-native async messaging
* When RabbitMQ must be kept 1:1, document RabbitMQ self-hosted on VM/AKS or a third-party managed RabbitMQ provider as a separate path.

---

## Lab 12B — Azure Event Hubs Kafka Endpoint

### Priority

**Optional**

### Nội dung

* Kafka
* Azure Event Hubs Kafka endpoint
* Event Streaming

### Liên hệ CSNP

```text
Compliance
Analytics
Shadow Stream
```

---

## Lab 13 — Azure DNS + Managed Certificates

### Nội dung

* DNS
* Azure DNS
* Container Apps custom domain and managed certificate, or Key Vault-backed certificate depending on ingress target
* HTTPS

Ví dụ:

```text
api.csnp.xyz
```

### Học được

* Domain Management
* TLS

---

## Lab 14 — Azure Front Door WAF

### Priority

**Required**

### Nội dung

* Azure Front Door WAF Policy
* OWASP Rules
* Rate Limiting
* Layer 7 Protection

### Liên hệ CSNP

```text
Fintech
Compliance
Public APIs
```

### Học được

* API Protection

---

# PHASE 7 — ADVANCED PLATFORM ENGINEERING

## Lab 15 — Azure Front Door/CDN

### Priority

**Để sau**

### Nội dung

* CDN
* Edge Caching

---

## Lab 16 — GitOps

### Nội dung

* ArgoCD
* GitOps
* AKS

### Học được

* Platform Delivery

---

## Lab 17 — External Secrets

### Nội dung

* Key Vault
* External Secrets Operator

### Học được

* Secret Automation

---

## Lab 18 — OpenTelemetry

### Nội dung

* OpenTelemetry
* Azure Application Insights
* Distributed Tracing

### Học được

* Observability Platform

---

## Lab 19 — Management Groups and Azure Policy

### Priority

**Optional**

### Nội dung

* Azure Management Groups
* Subscriptions
* Azure Policy
* Landing Zones

---

## Lab 20 — Disaster Recovery

### Nội dung

* Backup
* Restore
* Cross Region
* DR Strategy

---

# Azure AZ-104 THEORY TRACK (No Lab — Học song song)

Không bắt buộc làm lab riêng, nhưng bắt buộc nắm vững cho AZ-104 và nền tảng Azure production.

### Storage

* Blob access tiers: Hot, Cool, Cold, Archive
* Lifecycle Management
* Redundancy: LRS, ZRS, GRS, GZRS và read-access variants
* Azure Files
* Azure File Sync
* Azure NetApp Files

### Data Transfer

* Azure Data Box
* AzCopy
* Azure Storage Explorer

### File Services

* Azure Files
* Azure NetApp Files

### Networking Advanced

* VNet Peering
* VPN Gateway
* ExpressRoute
* Private Link

### Hybrid

* Azure Arc
* Hybrid networking patterns

### Enterprise

* Azure Management Groups
* Azure Landing Zones

### Edge Cases

* Azure Edge Zones
* Azure Stack HCI
* Azure Local

### Mapping gợi ý

```text
Azure Blob Storage   → Lab 1 + Theory
VNet  → Lab 3A/3B + Theory
Azure Database for PostgreSQL  → Lab 1, Lab 9 + Theory
```

---

# MILESTONES

## Azure AZ-104 + Platform Foundation

```text
Lab 0.5
Lab 1 → Lab 10
```

## CSNP Production Ready

```text
Lab 0.5
Lab 1, 2, 3A, 3B, 4, 5, 6, 7, 8, 9
Lab 11, 12A, 13, 14
```

(Không phụ thuộc AKS — theo kết luận ADR Lab 9.5)

## Senior Platform Engineer Track

```text
Lab 0.5
Lab 1 → Lab 20
```

Bao gồm AKS, GitOps, OpenTelemetry, DR.

---

# DEPENDENCY GRAPH (Requires / Produces)

Nguyên tắc:

* Mỗi lab khai báo rõ **Requires** (lab nào phải xong trước) và **Produces** (output gì cho lab sau dùng).
* Không lab nào được bắt đầu nếu chưa xong toàn bộ "Requires".
* Mọi lab có Terraform lưu state trên shared labs Azure Storage backend với key riêng. Nếu lab sau cần resource từ lab trước (`vnet_id`, `subnet_ids`, `nsg_ids`...), mặc định vẫn copy từ `terraform output` vào `terraform.tfvars` để dependency minh bạch; chỉ dùng `terraform_remote_state` khi lab ghi rõ.

| Lab | Requires | Produces |
| --- | --- | --- |
| Lab 0.5 — Cost Guardrail | None | Budget Alert đã set ($5/$10) |
| Lab 1 — Azure VM+Azure Database for PostgreSQL+Azure Blob Storage+Managed Identity+Azure Monitor | Lab 0.5 | WalletMinimal chạy trên Azure VM (default VNet), kinh nghiệm Managed Identity/NSG |
| Lab 2 — ACR+Azure Container Apps | Lab 1 | Container image trên ACR, Container App mẫu (default network) |
| Lab 3A — VNet Networking (Console) | Lab 2 | VNet 3-tier design đã verify bằng tay (`10.10.0.0/16`) |
| Lab 3B — VNet Networking (CLI) | Lab 3A | Azure CLI skill, hiểu resource dependency (sandbox `10.20.0.0/16`, throwaway) |
| Lab 4 — Terraform Platform Foundation (Network Only) | Lab 3A, Lab 3B | `vnet_id`, `public_subnet_ids`, `private_app_subnet_ids`, `private_data_subnet_ids`, `ingress_nsg_id`, `app_nsg_id`, `data_nsg_id` |
| Lab 5 — Terraform Container Apps Platform (= Terraform Lab 2 + Azure Database for PostgreSQL/Azure Blob Storage/Managed Identity) | Lab 4 | Container App chạy trong Custom VNet, ingress endpoint, Managed Identity/RBAC, **Azure Database for PostgreSQL endpoint (tự tạo, không phải từ Lab 4)**, Blob Storage |
| Lab 6 — Observability | Lab 5 | Dashboards, Alarms, Key Vault setup |
| Lab 7 — Auto Scaling & Resilience | Lab 6 | Scaling Policies, Health Check config |
| Lab 8 — CI/CD | Lab 5 | GitHub Actions pipeline (Build→ACR→Container Apps Deploy) |
| Lab 9 — Azure Database for PostgreSQL HA | Lab 8 | Azure PostgreSQL HA cluster, so sánh Azure Database for PostgreSQL vs Azure PostgreSQL HA |
| Lab 9.5 — Container Apps vs AKS ADR | Lab 9 | `ADR-XXXX-Container Apps-VS-AKS.md` |
| Lab 10 — AKS | Lab 9.5 | AKS cluster mapping với Container Apps concepts |
| Lab 11 — Azure Cache for Redis | Lab 5 | Cache layer, distributed lock pattern |
| Lab 12A — Azure Service Bus Messaging (Required) | Lab 11 | Queue/topic messaging, retry/DLQ pattern |
| Lab 12B — Azure Event Hubs Kafka endpoint (Optional) | Lab 12A | Kafka event streaming demo |
| Lab 13 — Azure DNS + managed certificates | Lab 5 | `api.csnp.xyz` DNS + TLS |
| Lab 14 — Front Door WAF (Required) | Lab 13 | Layer 7 protection rules |
| Lab 15 — Azure Front Door/CDN (Để sau) | Lab 14 | CDN config |
| Lab 16 — GitOps | Lab 10 | ArgoCD trên AKS |
| Lab 17 — External Secrets | Lab 16 | Key Vault ↔ AKS integration |
| Lab 18 — OpenTelemetry | Lab 16 | Distributed tracing trên AKS |
| Lab 19 — Management Groups and Azure Policy (Optional) | Lab 18 | Governance / Landing Zone design |
| Lab 20 — Disaster Recovery | Lab 18 | Backup/Restore cross-region |

---

# TRẠNG THÁI HIỆN TẠI (cập nhật 2026-06-19)

| Lab | Status |
| --- | --- |
| Lab 0.5 | Note rải trong từng lab (Estimated Cost), chưa tách riêng — chấp nhận được |
| Lab 1 | Done (Console), Terraform skeleton chưa apply |
| Lab 2 | Done (Console), Terraform skeleton chưa apply |
| Lab 3A / 3B | Done — đã archive bản Lab 3 cũ (Terraform-first, vi phạm triết lý) |
| Lab 4 | **Done.** Network-only (VNet/Subnet/NAT/NSG) — chốt scope, không gồm Azure VM/Azure Database for PostgreSQL/Azure Blob Storage/Managed Identity/Azure Monitor |
| Lab 5 | = Terraform hoá Lab 2, đặt vào Custom VNet + Azure Database for PostgreSQL/Azure Blob Storage/Managed Identity. **Code đã viết, chưa `terraform apply`** |
| Lab 6–20 | **Đã generate code/docs ngày 2026-06-24; cần cleanup Azure-native trước khi học theo nguyên xi.** Lab 19 intentionally docs-first vì blast radius cấp Azure tenant/subscription. |

---

# BACKLOG THỨ TỰ XỬ LÝ

1. ✅ Archive `lab-03-custom-vpc-networking` (đã làm)
2. ✅ Update root README + gộp ROADMAP.md (đang làm)
3. ✅ Chốt scope Lab 4 = Network only (Azure Database for PostgreSQL/Azure Blob Storage/Microsoft Entra ID / Azure RBAC chuyển hẳn sang Lab 5, không phải "Phase B-E" của Lab 4 nữa)
4. ⚠️ Cleanup Lab 00 → Lab 08 docs theo Azure-native trước khi học lại.
5. ⚠️ `terraform apply` Lab 5 sau cleanup (cần test thật — VNet/Subnet/NSG/Azure Database for PostgreSQL/Container Apps end-to-end).
6. ⚠️ Cleanup Lab 09 → Lab 20 docs/artifacts; apply từng lab vẫn phải theo dependency graph và cost guardrail.

---

# CHANGELOG (so với bản gốc 20-lab)

1. Thêm Lab 0.5 — Azure Cost Guardrail (trước Lab 1).
2. Giữ Azure PostgreSQL HA ở Phase 5 (sau CI/CD) — theo thứ tự platform-first, không phải database-specialist-first.
3. Thêm Lab 9.5 — Container Apps vs AKS ADR, output là file ADR thật.
4. Tách Lab 12 thành 12A Azure Service Bus Messaging (Required) và 12B Azure Event Hubs Kafka endpoint (Optional).
5. Đổi priority: Lab 14 WAF → Required, Lab 15 Azure Front Door/CDN → Để sau.
6. Lab 19 Multi Account → Optional.
7. Sửa milestone "CSNP Production Ready": loại bỏ Lab 10 (AKS).
8. Thêm section AZ-104 Theory Track (No Lab) để cover phần kiến thức thi không có trong hands-on lab.

