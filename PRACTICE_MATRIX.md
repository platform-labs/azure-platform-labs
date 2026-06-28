# Azure Labs Deliberate Practice Matrix

File này là bản đồ luyện tập nhanh. Chi tiết triển khai vẫn nằm trong `docs/*-hands-on.md` của từng lab.

| Lab | Console discovery | CLI verification | Failure drill | Rebuild target |
| --- | --- | --- | --- | --- |
| 00 | Cost Management, Budgets, Action Groups | `az consumption budget` / portal verification | Action group sai email hoặc budget threshold sai | Tự dựng guardrail và giải thích độ trễ billing |
| 01 | Managed Identity, Azure VM, PostgreSQL, Blob Storage, Azure Monitor | `az vm`, `az postgres flexible-server`, `az storage`, `az monitor` | Chặn NSG hoặc gỡ RBAC permission | Wallet API healthy từ Azure VM |
| 02 | ACR, Container Apps Environment, Container App, ingress, revision | `az acr`, `az containerapp`, Log Analytics query | Image tag sai hoặc probe/ingress sai | Build → push → Container App revision healthy |
| 03A | VNet resource map | `az network vnet/subnet/route-table/nsg` queries | Bỏ route association hoặc NSG rule | Tự dựng VNet 3-tier bằng Console |
| 03B | Map CLI output với Console | Chính các lệnh create/describe/delete | Xóa sai dependency order | VNet sandbox từ CLI rồi cleanup |
| 04 | Map HCL với VNet Console | Terraform output + `az network` queries | Route/NAT/NSG sai có chủ đích | Network foundation từ README |
| 05 | Container Apps/PostgreSQL/Blob/Managed Identity resource map | `az containerapp`, `az postgres`, `az storage`, `az role assignment` | Revision không pull image hoặc ingress/probe fail | Container Apps private-network stack healthy |
| 06 | Dashboard, alarm, logs, secret | Azure Monitor/Logs/Secrets CLI | Trigger app error hoặc CPU alarm | Tự dựng dashboard + alarms |
| 07 | Scaling activity, revisions | Container Apps replica/revision queries | Deploy image lỗi hoặc scale rule sai | Scaling rules + rollback/recovery |
| 08 | GitHub run + Container Apps deployment events | ACR image and Container Apps revision queries | Deploy bad SHA rồi rollback | Pipeline không dùng Azure access key |
| 09 | Azure PostgreSQL HA topology/events | Azure Database for PostgreSQL cluster/member queries | Controlled failover | Writer/reader + reconnect proof |
| 9.5 | Không tạo resource | Thu thập cost/ops evidence | Challenge decision bằng scenario mới | Tự viết ADR từ blank page |
| 10 | AKS cluster/node/add-ons | `az aks` + `kubectl` | Pod crash, bad readiness, Pending pod | Cluster + workload + HPA |
| 11 | Azure Cache for Redis topology/metrics | `az redis` + Redis CLI | Failover hoặc cache unavailable | Cache-aside có fallback |
| 12A | Service Bus namespace/queue/topic/metrics | `az servicebus` + client observation | Poison message → retry → DLQ | Producer/consumer idempotent |
| 12B | Azure Event Hubs Kafka endpoint cluster/metrics | Azure Event Hubs Kafka endpoint describe + Kafka client | Consumer lag/replay | Topic + two consumer groups |
| 13 | Azure DNS record, custom domain, managed certificate | DNS + `az containerapp hostname` / certificate queries | DNS/validation/hostname mismatch | HTTPS endpoint verified |
| 14 | Front Door WAF rules/sample requests | `az network front-door waf-policy` / portal inspection | Trigger managed/rate rule | Block proof without breaking healthy traffic |
| 15 | Front Door endpoint/routes/cache | `az afd` + curl headers | Wrong cache key or stale object | Explain hit/miss and purge safely |
| 16 | Argo CD app/sync/diff | `kubectl`/Argo CD CLI | Manual drift and bad Git commit | Git-only recovery |
| 17 | ESO status, target Secret | `kubectl describe` + Workload ID/RBAC checks | Break federated credential or property name | Rotation reaches workload |
| 18 | Application Insights service map/traces | Collector logs + trace lookup | Break exporter or downstream call | End-to-end trace with correlation |
| 19 | Management Groups/Azure Landing Zones discovery only | Policy validation/simulation | Find Azure Policy blast-radius issue | Management group / policy design from requirements |
| 20 | Backup jobs/recovery points | Azure Backup list/describe | Restore into isolated target | Measured RPO/RTO restore drill |

## Recommended repetitions by cost

- **Low-cost repeat often:** 00, 03B, 08 OIDC/RBAC design, 9.5, 16 manifests, 17 manifests, 18 manifests, 19.
- **Short-lived repeat:** 01, 02, 04–07, 11, 13–15.
- **Schedule and destroy same day:** 09, 10, 12A, 12B, 20 restore drills.

