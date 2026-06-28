# Lab 10 - Azure AKS

## Mục tiêu

Tạo AKS cluster + node pool trong private app subnets và deploy Wallet API bằng Deployment, Service, Ingress, HPA.

## Requires / Produces

- Requires: ADR Lab 9.5, VNet/subnet Lab 4.
- Produces: AKS cluster, node pool và Kubernetes manifests mapping từ Container Apps.

## Mapping

| Container Apps | Kubernetes |
| --- | --- |
| Container Apps Environment | AKS cluster |
| Container App template/revision | Pod template / rollout |
| Container App | Deployment + Service |
| Container Apps ingress | Ingress |
| Container Apps scale rule | HPA/KEDA |

## Cost guardrail

AKS control plane, Azure VM nodes, NAT và load balancer đều tính phí. `desired_size=2` chỉ dùng trong buổi lab; destroy ngay sau khi hoàn tất.

## Thực hành

Xem [hands-on](docs/lab-10-hands-on.md). Ingress controller chưa được tự động cài trong Terraform để người học hiểu rõ add-on/identity boundary; manifest Ingress chỉ hoạt động sau khi controller được cài.

## Cleanup

Xóa Ingress/Service trước để Azure Load Balancer/Public IP được dọn, rồi `terraform destroy`.

## Trạng thái

Code-ready, chưa apply.

