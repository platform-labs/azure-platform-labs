# Lab 15 - Azure Front Door/CDN

## Mục tiêu

Đặt Azure Front Door/CDN trước HTTPS ALB, ép HTTPS, hiểu cache key, TTL và origin protection.

## Requires / Produces

- Requires: Lab 14.
- Produces: Azure Front Door/CDN distribution trỏ ALB origin.

## Thiết kế lab

Default behavior dùng managed `CachingDisabled` vì Wallet API là dynamic. Một cache behavior `/public/*` dùng `CachingOptimized` để minh họa edge caching an toàn cho public content.

## Cost guardrail

Azure Front Door/CDN tính data transfer/request; invalidation ngoài quota miễn phí có thể phát sinh phí.

## Cleanup

Distribution phải disable trước khi Azure cho delete; `terraform destroy` có thể mất vài phút.

## Trạng thái

Code-ready, chưa apply.

