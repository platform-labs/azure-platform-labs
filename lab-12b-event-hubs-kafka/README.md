# Lab 12B - Azure Azure Event Hubs Kafka endpoint (Optional)

## Mục tiêu

Thực hành Kafka event streaming cho compliance/analytics shadow stream, không thay RabbitMQ command/event integration của Lab 12A.

## Requires / Produces

- Requires: Lab 12A.
- Produces: private Azure Event Hubs Kafka endpoint cluster với Microsoft Entra ID / Azure RBAC authentication.

## Architecture

```text
Wallet/Payment -> Kafka topic -> Compliance / Analytics consumers
```

## Cost guardrail

Azure Event Hubs Kafka endpoint có cluster capacity và data processing cost. Đây là lab optional; apply/test/destroy trong cùng buổi.

## Cleanup

Xóa producers/consumers rồi:

```bash
terraform destroy
```

## Trạng thái

Code-ready, chưa apply.

