# Lab 13 - Interview Notes

## Vì sao Azure managed certificates certificate phải cùng region ALB?

Regional services như ALB dùng certificate cùng region. Azure Front Door/CDN là ngoại lệ: certificate viewer phải ở `eastus`.

## Alias record khác CNAME?

Azure DNS alias có thể trỏ root/apex tới Azure resource và không tính DNS query theo cách CNAME thông thường; record vẫn là A/AAAA.

## DNS validation

Azure managed certificates kiểm tra CNAME chứng minh quyền kiểm soát domain và có thể tự renew khi record còn tồn tại và certificate còn được dùng.

