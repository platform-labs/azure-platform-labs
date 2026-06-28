# PRACTICE_SCHEDULE.md — Thứ tự thực hành Labs

> Nguyên tắc cốt lõi:
> - **Nhóm lab theo infrastructure dùng chung** → tránh apply/destroy Lab 4+5 nhiều lần thừa.
> - **Mỗi session: apply → làm hết lab trong session → destroy ngay trong ngày**.
> - Azure NAT Gateway, Azure Database for PostgreSQL, Azure PostgreSQL HA, AKS **không để chạy qua đêm**.
> - Mỗi lần rebuild Lab 4+5 = deliberate practice thêm 1 lượt — đây là điều tốt, không phải lãng phí.

---

## Dependency nhanh

```
Lab 4 output  →  Lab 5, Lab 9, Lab 10, Lab 11, Lab 12A, Lab 12B cần
Lab 5 output  →  Lab 6, Lab 7, Lab 8, Lab 13, Lab 14 cần
Lab 10 output →  Lab 16, Lab 17, Lab 18 cần
```

---

## SESSION 1 — Container Apps Operations Stack

**Infrastructure:** Lab 4 + Lab 5  
**Cost:** ~$0.08/hr | **Deadline:** Destroy trong ngày  
**Labs:** 4 → 5 → 6 → 7 → 8

### Bước 1 — Apply Lab 4

```bash
cd lab-04-terraform-platform-foundation/terraform

# Lấy IP hiện tại
curl -s https://ifconfig.me

# Tạo tfvars (không commit file này)
cp terraform.tfvars.example terraform.tfvars
# Điền các biến theo terraform.tfvars.example của lab

terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

**Lưu output Lab 4** — dùng cho Lab 5 và các lab cần VNet:

```bash
terraform output
# Copy toàn bộ output vào terraform.tfvars của Lab 5
```

| Output cần lưu | Dùng cho |
|---|---|
| `vnet_id` | Lab 5, 11, 12A, 12B |
| `public_subnet_ids` | Lab 5 nếu cần public ingress support |
| `private_app_subnet_ids` | Lab 5 (Container Apps), Lab 10 (AKS) |
| `private_data_subnet_ids` | Lab 5 (Azure Database for PostgreSQL), Lab 9 (Azure PostgreSQL HA), Lab 11 (Redis) |
| `ingress_nsg_id` | Lab 5 nếu có ingress subnet riêng |
| `app_nsg_id` | Lab 5, Lab 11 |
| `data_nsg_id` | Lab 5, Lab 9 |

### Bước 2 — Apply Lab 5

```bash
cd ../../lab-05-terraform-container-apps-platform/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền từ output Lab 4:
#   vnet_id, public_subnet_ids, private_app_subnet_ids,
#   private_data_subnet_ids, ingress_nsg_id,
#   app_nsg_id, data_nsg_id
# Điền thêm:
#   db_password = "..." (hoặc dùng TF_VAR_db_password)
#   container_image = "<acr-login-server>/csnp-platform-wallet-api:<tag>"

terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply

# Verify service healthy
terraform output container_app_url
curl "https://$(terraform output -raw container_app_url)/health"
```

**Lưu output Lab 5** — dùng cho Lab 6, 7, 8, 13, 14:

```bash
terraform output
```

| Output cần lưu | Dùng cho |
|---|---|
| `container_app_name` | Lab 6, Lab 7, Lab 8 |
| `container_app_url` | Lab 13 |
| `acr_login_server` | Lab 8 |
| `acr_repository_name` | Lab 8 |
| `managed_identity_client_id` | Lab 8, Lab 17 |

### Bước 3 — Apply Lab 6 (Observability)

```bash
cd ../../lab-06-observability/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền: resource_group_name, container_app_name, log_analytics_workspace_id
# Optional: alarm_email = "your@email.com"

terraform init && terraform apply

# Verify
az monitor metrics alert list \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --output table

az monitor app-insights component show \
  --app "$(terraform output -raw application_insights_name)" \
  --resource-group "$(terraform output -raw resource_group_name)"
```

### Bước 4 — Apply Lab 7 (Auto Scaling)

```bash
cd ../../lab-07-auto-scaling-resilience/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền: resource_group_name, container_app_name (từ Lab 5 output)

terraform init && terraform apply

# Verify scaling/revision state
az containerapp revision list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_CONTAINER_APP" \
  --output table
```

### Bước 5 — Apply Lab 8 (CI/CD)

```bash
cd ../../lab-08-cicd/terraform

# Repo hiện tại dùng source app ở lab-02-acr-container-apps/src/Lab02.WalletMinimal
# terraform.tfvars đã được chuẩn bị cho:
#   github_owner      = "platform-labs"
#   github_repository = "azure-platform-labs"
#   github_branch     = "main"
# Nếu fork sang repo khác, sửa 3 giá trị này trước khi apply.

terraform fmt
terraform validate
terraform plan
terraform apply

# Copy các giá trị này sang GitHub Actions repository variables
terraform output github_actions_variables
```

Workflow đã được đặt tại:

```text
.github/workflows/build-test-deploy.yml
```

Các variables cần có trong GitHub Actions:

```text
AZURE_CLIENT_ID=<managed-identity-or-app-client-id>
AZURE_TENANT_ID=<tenant-id>
AZURE_SUBSCRIPTION_ID=<subscription-id>
AZURE_RESOURCE_GROUP=csnp-lab05-rg
AZURE_CONTAINER_APP=csnp-platform-wallet-api
ACR_LOGIN_SERVER=csnpregistry.azurecr.io
ACR_REPOSITORY=csnp-platform-wallet-api
```

Push lên `main` và verify pipeline:

```bash
az acr repository show-tags \
  --name "${ACR_LOGIN_SERVER%%.azurecr.io}" \
  --repository csnp-platform-wallet-api \
  --orderby time_desc \
  --top 5

az containerapp revision list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_CONTAINER_APP" \
  --output table
```

### ⚠️ DESTROY Session 1

**Thứ tự destroy — quan trọng, không làm ngược:**

```bash
# Lab 8
cd lab-08-cicd/terraform && terraform destroy

# Lab 7
cd ../../lab-07-auto-scaling-resilience/terraform && terraform destroy

# Lab 6
cd ../../lab-06-observability/terraform && terraform destroy

# Lab 5 (Azure Database for PostgreSQL mất ~5 phút)
cd ../../lab-05-terraform-container-apps-platform/terraform && terraform destroy

# Lab 4 (Azure NAT Gateway mất ~2 phút)
cd ../../lab-04-terraform-platform-foundation/terraform && terraform destroy

# Verify không còn resource tính tiền chính
az network nat gateway list --output table
az postgres flexible-server list --output table
az containerapp list --output table
```

---

## SESSION 2 — Azure PostgreSQL HA (Database Day)

**Infrastructure:** Lab 4 only  
**Cost:** Azure Database for PostgreSQL Flexible Server HA — **⚠️ destroy cùng ngày**  
**Labs:** 4 → 9

### Apply Lab 4

*(giống Session 1, bước 1 — lần này không cần nhìn guide)*

### Apply Lab 9 (Azure PostgreSQL HA)

```bash
cd lab-09-azure-postgresql-ha/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền từ Lab 4 output:
#   private_data_subnet_ids, data_nsg_id

terraform init && terraform apply

# Failover drill
az postgres flexible-server restart \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$POSTGRES_SERVER_NAME"

# Verify writer/reader endpoint
az postgres flexible-server show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$POSTGRES_SERVER_NAME" \
  --query "{name:name,state:state,ha:highAvailability.mode,location:location}"
```

### DESTROY Session 2

```bash
cd lab-09-azure-postgresql-ha/terraform && terraform destroy
cd ../../lab-04-terraform-platform-foundation/terraform && terraform destroy
```

**Lab 9.5 (ADR):** Làm bất kỳ lúc nào, không cần infra.

---

## SESSION 3 — CSNP Production Services

**Infrastructure:** Lab 4 + Lab 5  
**Cost:** ~$0.12/hr | **Deadline:** Destroy trong ngày  
**Labs:** 4 → 5 → 11, 12A, (12B) → 13 → 14

### Apply Lab 4 → Lab 5

*(giống Session 1 — rebuild từ memory, không nhìn guide)*

### Apply Lab 11 (Azure Cache for Redis)

```bash
cd lab-11-azure-cache-redis/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền từ Lab 4: vnet_id, private_data_subnet_ids, app_nsg_id

terraform init && terraform apply

# Test Redis connectivity từ Container Apps task hoặc bastion
az redis show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$REDIS_NAME" \
  --query "{name:name,hostName:hostName,sku:sku.name,provisioningState:provisioningState}"
```

### Apply Lab 12A (Azure Service Bus — Required)

```bash
cd ../../lab-12a-service-bus-messaging/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền Azure Service Bus namespace/queue/topic settings

terraform init && terraform apply

# Verify namespace/queues/topics
az servicebus namespace list --output table
az servicebus queue list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --namespace-name "$SERVICEBUS_NAMESPACE" \
  --output table
```

### Apply Lab 12B (Azure Event Hubs Kafka endpoint — Optional)

```bash
cd ../../lab-12b-event-hubs-kafka/terraform
terraform init && terraform apply
```

### Apply Lab 13 (Azure DNS + Azure managed certificates)

```bash
cd ../../lab-13-azure-dns-certificates/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền từ Lab 5:
#   container_app_url hoặc Front Door origin host
# Điền thêm:
#   domain_name = "api.csnp.xyz"
#   dns_zone_name = "csnp.xyz"

terraform init && terraform apply

# Verify DNS + TLS
dig api.csnp.xyz
curl -I https://api.csnp.xyz/health
```

### Apply Lab 14 (Azure WAF)

```bash
cd ../../lab-14-azure-waf/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền: Front Door profile/endpoint/origin settings

terraform init && terraform apply

# Test WAF block
az network front-door waf-policy list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --output table
```

### ⚠️ DESTROY Session 3

```bash
cd lab-14-azure-waf/terraform && terraform destroy
cd ../../lab-13-azure-dns-certificates/terraform && terraform destroy
cd ../../lab-12b-event-hubs-kafka/terraform && terraform destroy   # nếu có apply
cd ../../lab-12a-service-bus-messaging/terraform && terraform destroy
cd ../../lab-11-azure-cache-redis/terraform && terraform destroy
cd ../../lab-05-terraform-container-apps-platform/terraform && terraform destroy
cd ../../lab-04-terraform-platform-foundation/terraform && terraform destroy
```

---

## SESSION 4 — AKS + GitOps Track

**Infrastructure:** Lab 4 + Lab 10 (AKS)  
**Cost:** AKS control plane $0.10/hr + Azure VM nodes ~$0.04/hr — **⚠️ destroy cùng ngày**  
**Labs:** 4 → 10 → 16 → 17 → 18

### Apply Lab 4

*(lần thứ 3+ — phải thuần thục, apply dưới 10 phút)*

### Apply Lab 10 (AKS)

```bash
cd lab-10-aks/terraform

cp terraform.tfvars.example terraform.tfvars
# Điền từ Lab 4: private_app_subnet_ids
# Điền thêm: public_access_cidrs = ["<your_ip>/32"]

terraform init && terraform apply  # ~15 phút

# Configure kubectl
az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name csnp-lab10 \
  --overwrite-existing

kubectl get nodes
kubectl get pods -A
```

### Apply Lab 16 (GitOps — ArgoCD)

```bash
# ArgoCD manifest trong lab-16-gitops-argocd/argocd/
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply ArgoCD Application
kubectl apply -f ../../lab-16-gitops-argocd/argocd/project.yaml
kubectl apply -f ../../lab-16-gitops-argocd/argocd/application.yaml

# Drift drill: thay đổi trực tiếp trên cluster, verify ArgoCD sync lại
```

### Apply Lab 17 (External Secrets)

```bash
cd lab-17-external-secrets/terraform
terraform init && terraform apply

# Apply Kubernetes manifests
kubectl apply -f ../../lab-17-external-secrets/kubernetes/
```

### Apply Lab 18 (OpenTelemetry)

```bash
# Apply OTel collector manifests
kubectl apply -f ../../lab-18-opentelemetry/kubernetes/

# Verify traces trong Application Insights
az monitor app-insights query \
  --app "$APPLICATIONINSIGHTS_APP_ID" \
  --analytics-query "traces | take 10"
```

### ⚠️ DESTROY Session 4

```bash
# Xóa workloads trước, nodes tự terminate → dừng tính tiền node nhanh nhất
kubectl delete namespace argocd
kubectl delete all --all -n default

cd lab-10-aks/terraform && terraform destroy   # ~10 phút
cd ../../lab-04-terraform-platform-foundation/terraform && terraform destroy

# Verify AKS cluster đã xóa
az aks list --output table
az vmss list --resource-group "$AKS_NODE_RESOURCE_GROUP" --output table
```

---

## Labs độc lập — Làm bất kỳ lúc nào

| Lab | Cần gì | Ghi chú |
|---|---|---|
| Lab 9.5 — Container Apps vs AKS ADR | Không cần infra | Review `docs/ADR-0001-Container Apps-VS-AKS.md`, đổi status → Accepted |
| Lab 15 — Azure Front Door/CDN | Không cần Lab 4/5 | Có thể làm standalone |
| Lab 19 — Multi Account | Không cần infra | Docs-first, không tạo resource |
| Lab 20 — Disaster Recovery | Bất kỳ session nào có Azure Database for PostgreSQL | Azure Backup chọn resource theo tag |

---

## Tổng quan thứ tự

```
Session 1  Lab 4 → 5 → 6 → 7 → 8          Container Apps Ops — quan trọng nhất
    ↓
Session 2  Lab 4 → 9                        Azure PostgreSQL HA — destroy cùng ngày
    ↓
Lab 9.5                                     ADR — anytime, không infra
    ↓
Session 3  Lab 4 → 5 → 11, 12A → 13 → 14  CSNP Production
    ↓
Session 4  Lab 4 → 10 → 16 → 17 → 18      AKS + GitOps — tốn kém nhất
    ↓
Anytime    Lab 15, 19, 20
```

---

## Milestone

| Milestone | Hoàn thành sau |
|---|---|
| Azure AZ-104 foundation | Session 1 + Session 2 |
| **CSNP Production Ready** | Session 1 + 2 + 3 |
| Senior Platform Engineer | Session 1 + 2 + 3 + 4 |

---

## Quick cost check

```bash
# Chạy trước khi kết thúc ngày — kiểm tra resource còn sót
az network nat gateway list --output table
az postgres flexible-server list --output table
az containerapp list --output table
az aks list --output table
az redis list --output table
az servicebus namespace list --output table
az eventhubs namespace list --output table
az network front-door list --output table
```

> Nếu có bất kỳ resource nào trong danh sách trên còn `available/active` mà không cần thiết → destroy ngay.

