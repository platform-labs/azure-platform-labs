# Lab 12A - Hands-on

## Deliberate practice loop

1. **Mental model:** vẽ producer → queue/topic/subscription → consumer → retry/DLQ và delivery acknowledgement.
2. **Console discovery:** xem namespace, queue/topic, subscription, active/dead-letter message count và metrics trên resource Terraform tạo.
3. **Implementation:** apply Service Bus, kết nối MassTransit, publish và consume message.
4. **CLI verification:** dùng `az servicebus` và client/metrics chứng minh message flow.
5. **Failure drill:** poison message phải đi qua retry policy rồi DLQ; consumer không được retry vô hạn.
6. **Rebuild without guide:** tự dựng producer/consumer idempotent và retry/DLQ topology.
7. **Cleanup/cost audit:** destroy broker cùng ngày; không log hoặc commit broker password.
8. **Interview recap:** giải thích at-least-once, idempotency, retry và Service Bus trade-offs.

Theo dõi lượt luyện: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Kết nối ứng dụng bằng Service Bus namespace endpoint. Ưu tiên Managed Identity/RBAC; nếu dùng connection string thì không log hoặc commit secret.

## MassTransit exercise

- publish `PaymentRequested`;
- consumer retry ngắn cho transient failure;
- sau retry chuyển fault message sang error/DLQ queue;
- lưu message ID trong inbox table để consumer idempotent;
- quan sát redelivery, queue depth và poison message.

## Verify

```bash
az servicebus namespace show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$SERVICEBUS_NAMESPACE"

az servicebus queue list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --namespace-name "$SERVICEBUS_NAMESPACE" \
  --output table
```

Không log connection string hoặc SAS key.

