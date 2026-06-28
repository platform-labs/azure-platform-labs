# Lab 12A - Azure Service Bus Messaging

## Mục tiêu

Triển khai Azure Service Bus namespace/queue/topic, kết nối MassTransit và thực hành retry, dead-letter queue, idempotent consumer.

## Requires / Produces

- Requires: Lab 11 và private subnets Lab 4.
- Produces: Service Bus namespace, queue/topic/subscription và RBAC/connection settings cho Container Apps.

## Cost guardrail

Service Bus Standard/Premium có chi phí theo namespace và usage. Dùng cấu hình nhỏ nhất đủ lab và destroy trong cùng buổi nếu không cần giữ lại.

## Secret warning

Connection string/password là Terraform sensitive variable nhưng vẫn nằm trong encrypted remote state. Dùng password lab riêng, không tái sử dụng.

## Cleanup

```bash
terraform destroy
```

## Tài liệu

- [Hands-on](docs/lab-12a-hands-on.md)
- [Interview notes](docs/lab-12a-interview-notes.md)

## Trạng thái

Code-ready, chưa apply.


