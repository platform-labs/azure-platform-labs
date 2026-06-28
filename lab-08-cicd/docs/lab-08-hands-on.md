# Lab 08 - Hands-on

## Deliberate practice loop

1. **Mental model:** vẽ Git push -> GitHub OIDC -> azure/login -> ACR -> Container App revision.
2. **Console discovery:** xem federated credential, GitHub run, ACR image digest và Container Apps revision events.
3. **Implementation:** apply OIDC role, cấu hình repository variables và chạy workflow.
4. **CLI verification:** query ACR tag/digest và Container Apps revision.
5. **Failure drill:** deploy bad image rồi rollback về SHA tốt gần nhất.
6. **Rebuild without guide:** viết lại workflow tối thiểu không dùng Azure client secret dài hạn.
7. **Cleanup/cost audit:** xóa workflow test/role nếu không dùng; dọn image tags và failed revisions khi cần.
8. **Interview recap:** giải thích CI/CD boundary, immutable artifact và OIDC trust conditions.

Theo dõi lượt luyện: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

## Source layout

Lab này dùng code WalletMinimal ở:

```text
lab-02-acr-container-apps/src/Lab02.WalletMinimal
```

Workflow đã hardcode `APP_DIR` theo path trên để chạy:

- `dotnet restore Lab02.WalletMinimal.sln`
- `dotnet build Lab02.WalletMinimal.sln --configuration Release`
- `docker build` từ đúng thư mục chứa `Dockerfile`

## Terraform

Từ `lab-08-cicd/terraform`:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output github_actions_variables
```

Nếu account đã có GitHub OIDC provider, đặt:

```hcl
create_oidc_provider       = false
azure_client_id       = "<managed-identity-or-app-client-id>"
azure_tenant_id       = "<tenant-id>"
azure_subscription_id = "<subscription-id>"
```

Với repo hiện tại, trust policy phải có subject:

```text
repo:platform-labs/azure-platform-labs:ref:refs/heads/main
repo:platform-labs/azure-platform-labs:environment:dev
```

Deploy job đang dùng `environment: dev`, nên GitHub OIDC sẽ gửi subject dạng `environment:dev`. Nếu bỏ `environment` trong workflow thì subject sẽ quay về dạng `ref:refs/heads/main`.

## Container App deploy inputs

Container Apps không dùng ECS task definition. Workflow deploy bằng:

```bash
az containerapp update \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_CONTAINER_APP" \
  --image "$ACR_LOGIN_SERVER/$ACR_REPOSITORY:$GITHUB_SHA"
```

File `lab-08-cicd/containerapp-deploy-vars.example.json` chỉ là ví dụ các giá trị cần truyền vào workflow.

## GitHub variables

Tạo Actions variables, không phải secrets:

- `AZURE_CLIENT_ID`: client id của identity/app registration dùng cho OIDC.
- `AZURE_TENANT_ID`: tenant id.
- `AZURE_SUBSCRIPTION_ID`: subscription id.
- `AZURE_RESOURCE_GROUP`: resource group chứa Container App.
- `AZURE_CONTAINER_APP`: tên Container App.
- `ACR_LOGIN_SERVER`: ví dụ `csnpregistry.azurecr.io`.
- `ACR_REPOSITORY`: `csnp-platform-wallet-api`, là tên repository, không phải full URI.

## Verify

- PR chỉ chạy restore/build/test.
- Push `main` phải tạo ACR tag bằng commit SHA.
- Container App revision mới phải active/healthy.
- GitHub job phải dùng OIDC qua `azure/login`, không dùng client secret dài hạn.

```bash
az acr repository show-tags \
  --name "${ACR_LOGIN_SERVER%%.azurecr.io}" \
  --repository csnp-platform-wallet-api \
  --orderby time_desc \
  --top 5

az containerapp revision list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_CONTAINER_APP" \
  --query "[?properties.active].{name:name,traffic:properties.trafficWeight,created:properties.createdTime}" \
  --output table
```

## Rollback drill

Deploy một image lỗi health check, quan sát revision lỗi không nhận traffic, sau đó redeploy SHA tốt gần nhất bằng cách revert commit hoặc chạy workflow từ commit tốt.

## Cleanup

Trước khi destroy Lab 8, disable hoặc xóa workflow để tránh push mới cố dùng federated credential đã bị xóa.

