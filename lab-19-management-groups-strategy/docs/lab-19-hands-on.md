# Lab 19 - Hands-on Design Exercise

## Deliberate practice loop

1. **Mental model:** vẽ Organization root → OUs → accounts → Azure Policy/identity/resource policies và centralized security services.
2. **Console discovery:** chỉ xem Management Groups/Azure Landing Zones trong sandbox hoặc read-only; không thay organization thật.
3. **Implementation:** tạo OU/account ownership matrix, guardrail catalog và account-vending workflow trên giấy/code.
4. **CLI verification:** validate policy JSON và dùng simulator/read-only queries khi có sandbox organization.
5. **Failure drill:** review một Azure Policy quá rộng có thể khóa admin/global services; viết exception/recovery path.
6. **Rebuild without guide:** từ yêu cầu dev/UAT/pro/security, tự thiết kế landing zone.
7. **Cleanup/cost audit:** không có resource lab; xóa account IDs/email nhạy cảm khỏi artifact.
8. **Interview recap:** giải thích account boundary, OU, Azure Policy “does not grant” và delegated admin.

Theo dõi lượt luyện: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

## 1. Define account boundaries

Tạo bảng cho account owner, billing owner, data classification, region policy, break-glass và log retention.

## 2. Central capabilities

- Organization CloudTrail -> immutable Log Archive.
- GuardDuty/Security Hub delegated admin.
- Central Microsoft Entra ID / Azure RBAC Identity Center.
- Network account sở hữu Transit Gateway/egress nếu architecture cần.

## 3. Azure Policy simulation

Review policy samples bằng Microsoft Entra ID / Azure RBAC Access Analyzer/Management Groups policy simulator trong sandbox organization. Azure Policy không cấp quyền; nó chỉ giới hạn maximum permission.

## 4. Account vending

Định nghĩa workflow có approval, baseline stack, budget, contacts, tags và decommission runbook trước khi dùng Azure Landing Zones Account Factory.

