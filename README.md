# platforms/azure/labs

Learning / POC / experiments cho Azure. **Không phải production infra.**

Đây là Azure learning track cho CSNP. Nó giữ triết lý học từ
`aws-platform-labs`, nhưng nội dung phải đi theo Azure-native resource model,
không phải search/replace thuật ngữ AWS.

| AWS gốc | Azure tương đương |
| --- | --- |
| EC2 | Azure Virtual Machines |
| RDS / Aurora PostgreSQL | Azure Database for PostgreSQL Flexible Server |
| S3 | Azure Blob Storage |
| ECR | Azure Container Registry |
| ECS/Fargate | Azure Container Apps |
| ECS Task Definition / ALB / Target Group | Container App template, revision, ingress |
| EKS | Azure Kubernetes Service |
| CloudWatch | Azure Monitor + Log Analytics + Application Insights |
| Secrets Manager / KMS | Azure Key Vault |
| Route 53 / ACM | Azure DNS + managed certificates |
| CloudFront / WAF | Azure Front Door + WAF |
| ElastiCache Redis | Azure Cache for Redis |
| Amazon MQ / MSK | Azure Service Bus, RabbitMQ self-hosted nếu cần RabbitMQ 1:1, Event Hubs Kafka endpoint |
| Organizations / SCP | Management Groups / Azure Policy |

Các file trong repo cũ có thể vẫn còn dấu vết AWS. Khi gặp thuật ngữ như
ALB, Target Group, Task Definition, IGW, SG, RDS, ECR, ECS trong Azure docs,
hãy coi đó là backlog cleanup trừ khi đoạn đó đang so sánh trực tiếp AWS với
Azure.

Chạy `bootstrap/` trước khi `terraform init` các lab có Terraform.


