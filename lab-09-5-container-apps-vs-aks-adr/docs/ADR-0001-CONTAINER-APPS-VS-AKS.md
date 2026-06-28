# ADR-0001: Azure Container Apps hay AKS cho CSNP

- Status: Proposed
- Date: 2026-06-24
- Decision owners: Platform, Security, Application Architecture

## Context

CSNP hiện cần chạy nhiều HTTP API và background worker trên Azure. Team đã có kinh nghiệm Kubernetes on-premises nhưng Azure platform mới đang được xây dựng. Mục tiêu gần hạn là production-ready với blast radius nhỏ, least privilege, quan sát được và chi phí vận hành hợp lý.

## Decision drivers

| Driver | Trọng số | Azure Container Apps | AKS |
| --- | ---: | ---: | ---: |
| Time-to-production | 5 | 5 | 3 |
| Operational simplicity | 5 | 5 | 2 |
| Workload portability | 3 | 2 | 5 |
| Ecosystem/extensibility | 3 | 3 | 5 |
| Fine-grained platform APIs | 3 | 3 | 5 |
| Cost at current scale | 4 | 4 | 2 |
| Existing CSNP skills | 3 | 3 | 4 |
| Weighted total |  | **86** | **76** |

Điểm là giả định ban đầu, phải cập nhật bằng dữ liệu của team.

## Decision

Chọn **Azure Container Apps cho production đầu tiên**. AKS được duy trì như migration option và learning track, không phải dependency để CSNP production-ready.

## Rationale

- Container Apps loại bỏ control-plane/add-on/node lifecycle khỏi critical path.
- Container Apps phù hợp workload stateless hiện tại và giảm patching.
- Microsoft Entra ID / Azure RBAC task role, ALB, Azure Monitor, Key Vault tích hợp trực tiếp.
- Team có thể tập trung SLO, security và delivery trước khi xây internal Kubernetes platform.

## Consequences

### Positive

- Ít moving parts, nhanh đạt baseline vận hành.
- Chi phí control plane và add-on thấp hơn ở quy mô hiện tại.
- Blast radius và ownership dễ giải thích.

### Negative

- Tăng phụ thuộc Azure-specific APIs.
- Không dùng trực tiếp Helm/operator/service mesh ecosystem.
- Một số workload đặc thù có thể cần Azure VM capacity provider hoặc nền tảng khác.

## Khi nào xem xét lại AKS?

Mở lại ADR khi ít nhất một trigger xảy ra:

- cần operator/CRD hoặc scheduling capability Container Apps không đáp ứng;
- số service/team khiến platform API chuẩn Kubernetes tạo giá trị rõ;
- yêu cầu portability được tài trợ và đo lường;
- có đội sở hữu AKS control plane, upgrades, add-ons, policy và on-call;
- TCO 12 tháng cho thấy AKS tốt hơn sau khi tính cả engineering time.

## Migration strategy

1. Chuẩn hóa container contract: health endpoint, graceful shutdown, logs stdout, config/secret injection.
2. Giữ app stateless; database/cache/message broker dùng managed services.
3. Dùng OpenTelemetry và deployment metadata độc lập orchestrator.
4. Lab 10 mapping Container Apps service sang Deployment/Service/Ingress/HPA.
5. Pilot một service ít rủi ro; đo cost, lead time, incidents.
6. Chỉ migrate theo service, không big-bang.

## Rejected alternatives

- AKS ngay lập tức: tăng operational surface trước khi có nhu cầu đủ mạnh.
- Tự quản Kubernetes trên Azure VM: undifferentiated heavy lifting, không phù hợp mục tiêu lab/platform.
- Container Apps Azure VM launch type mặc định: thêm node management khi Container Apps đã đáp ứng workload hiện tại.

