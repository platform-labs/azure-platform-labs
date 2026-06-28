# Lab 17 - Hands-on

## Deliberate practice loop

1. **Mental model:** pod/service account → OIDC/STS → Microsoft Entra ID / Azure RBAC role → Key Vault/Key Vault keys → Kubernetes Secret.
2. **Console discovery:** xem Microsoft Entra ID / Azure RBAC trust policy, secret metadata và ESO status; không đọc secret value trong log.
3. **Implementation:** cài ESO, apply Microsoft Entra ID / Azure RBAC role/store/external secret và annotate service account.
4. **CLI verification:** `kubectl describe`, ESO conditions và STS/Microsoft Entra ID / Azure RBAC checks.
5. **Failure drill:** sai `sub`, secret property hoặc Key Vault keys permission; phân biệt auth, lookup và decrypt errors.
6. **Rebuild without guide:** từ secret ARN + OIDC issuer, tự đưa target Secret tới Ready.
7. **Cleanup/cost audit:** xóa ExternalSecret/Store/role đúng thứ tự; giữ source secret nếu còn consumer.
8. **Interview recap:** giải thích ESO không loại bỏ Kubernetes Secret và rotation cần app reload.

Theo dõi lượt luyện: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

1. Cài ESO bằng Helm chart chính thức.
2. Apply Terraform với OIDC provider ARN/issuer và source secret ARN.
3. Annotate service account `external-secrets` bằng output Microsoft Entra ID / Azure RBAC role ARN.
4. Thay ARN/region trong manifests rồi apply.

```bash
kubectl apply -f kubernetes/
kubectl describe externalsecret wallet-db -n wallet
kubectl get secret wallet-db -n wallet
```

Không dùng `kubectl get secret -o yaml` trong log CI. Rotate source secret và quan sát refresh.

