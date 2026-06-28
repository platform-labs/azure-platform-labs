# Lab 09.5 - Deliberate Practice

## 1. Mental model

Viết decision drivers trước khi đọc ADR mẫu: workload shape, team skill, operations, compliance, portability, cost và migration reversibility.

## 2. Console discovery

Không tạo resource. Xem Container Apps/AKS pricing, service quotas và operational surfaces để thu thập evidence; không chọn công nghệ từ cảm giác.

## 3. Implementation

Copy ADR sang một file nháp mới, xóa phần Decision/Rationale, rồi tự điền context, alternatives, matrix và consequences.

## 4. CLI verification

Dùng Azure CLI thu thập dữ liệu hiện hữu như số Container Apps services, task definitions, AKS clusters và account quotas nếu có. Evidence phải được ghi ngày thu thập.

## 5. Failure drill

Đưa vào một scenario làm quyết định hiện tại yếu đi, ví dụ cần CRD/operator hoặc team không có Kubernetes on-call. Xác định decision trigger có buộc mở lại ADR không.

## 6. Rebuild without guide

Viết ADR Container Apps vs AKS từ blank page trong 30 phút, sau đó mới diff với [`ADR-0001-Container Apps-VS-AKS.md`](./ADR-0001-Container Apps-VS-AKS.md).

## 7. Cleanup and cost audit

Không có resource để cleanup. Xóa dữ liệu account nhạy cảm khỏi notes và giữ assumptions/cost calculations có nguồn.

## 8. Interview recap

Trình bày quyết định trong 5 phút: “Why Container Apps today, when AKS tomorrow?”, gồm cả điều kiện khiến mình đổi ý.

Theo dõi lượt luyện: [`../../DELIBERATE_PRACTICE.md`](../../DELIBERATE_PRACTICE.md).

