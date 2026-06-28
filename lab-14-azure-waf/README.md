# Lab 14 - Azure WAF

## Mục tiêu

Bảo vệ public ALB bằng Azure Managed Rules, known-bad-input rules và rate-based rule; bật sampled requests và Azure Monitor metrics.

## Requires / Produces

- Requires: Lab 13 HTTPS ALB.
- Produces: regional Web ACL association với ALB.

## Safety

Bắt đầu managed rule ở `count` khi onboarding production traffic để đo false positive. Lab mặc định `block`; chỉ dùng endpoint lab.

## Cleanup

```bash
terraform destroy
```

## Trạng thái

Code-ready, chưa apply.

