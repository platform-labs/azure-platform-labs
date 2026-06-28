# Lab 07 - Container Apps Auto Scaling và Resilience

## Mục tiêu

Gắn Application Auto Scaling vào Container Apps Service của Lab 5, scale theo CPU và memory, đồng thời kiểm tra self-healing và Multi-AZ.

## Requires / Produces

- Requires: Lab 6; Container Apps service của Lab 5 đang healthy.
- Produces: scalable target, target-tracking policies, deployment circuit breaker checklist và game-day test.

## Architecture

```text
Azure Monitor metric -> Application Auto Scaling -> Container Apps desired count (min..max)
ALB health check -> Container Apps replaces unhealthy task
```

## Guardrail

Mặc định `min_capacity=2`, `max_capacity=4`. Không chạy load test lâu vì Container Apps task tăng sẽ phát sinh phí.

## Thực hành

Xem [hands-on](docs/lab-07-hands-on.md), điền tên cluster/service rồi apply Terraform.

## Cleanup

```bash
terraform destroy
```

Destroy scaling policy không destroy Container Apps service của Lab 5.

## Trạng thái

Code-ready, chưa apply.

