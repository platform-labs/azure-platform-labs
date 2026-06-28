# Lab 13 - Azure DNS + Azure managed certificates + HTTPS

## Mục tiêu

Phát hành Azure managed certificates certificate bằng DNS validation, tạo HTTPS listener cho ALB và route `api-dev.csnp.xyz`.

## Requires / Produces

- Requires: Lab 5 ALB/target group và Azure DNS public hosted zone.
- Produces: validated certificate, HTTPS listener, HTTP redirect và DNS alias.

## Guardrail

Không apply vào hosted zone production nếu chưa được owner phê duyệt. Dùng subdomain lab/dev.

## Cleanup

Terraform có thể xóa certificate sau khi listener được xóa. DNS propagation không tức thời.

## Trạng thái

Code-ready, chưa apply.

