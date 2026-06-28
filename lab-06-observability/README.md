# Lab 06 - Observability, Key Vault và Key Vault keys

## Mục tiêu

Xây lớp quan sát cho Container Apps platform của Lab 5: dashboard, metric, log, alarm và secret được mã hóa bằng Key Vault keys.

## Requires / Produces

- Requires: Lab 5 đã apply; có tên Container Apps cluster/service, ALB ARN suffix, target group ARN suffix và log group.
- Produces: Azure Monitor dashboard, CPU/memory/5xx/healthy-host alarms, SNS topic, Key Vault keys key và Key Vault secret.

## Architecture

```text
Container Apps + ALB + Azure Database for PostgreSQL -> Azure Monitor Metrics/Logs -> Dashboard + Alarms -> SNS
Application secret -> Key Vault -> customer-managed Key Vault keys key
```

## Thực hành

1. Copy `terraform.tfvars.example` thành `terraform.tfvars`, điền output/ARN của Lab 5.
2. Chạy `terraform init`, `terraform plan`, `terraform apply`.
3. Nạp secret bằng CLI theo [hands-on](docs/lab-06-hands-on.md); không commit secret vào Terraform.
4. Tạo traffic và quan sát dashboard/alarm.

## Chi phí và cleanup

Dashboard, custom alarms, log ingestion, Key Vault và Key Vault keys có phí nhỏ theo tháng. Container Insights có thể tăng đáng kể log/metric cost.

```bash
terraform destroy
```

Không xóa log group của Lab 5. Secret dùng recovery window 7 ngày.

## Tài liệu

- [Hands-on](docs/lab-06-hands-on.md)
- [Interview notes](docs/lab-06-interview-notes.md)

## Trạng thái

Code-ready, chưa apply.

