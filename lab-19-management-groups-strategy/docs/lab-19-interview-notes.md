# Lab 19 - Interview Notes

## Vì sao multi-account?

Account là isolation boundary mạnh cho billing, quotas, Microsoft Entra ID / Azure RBAC và blast radius. OU giúp áp guardrail theo nhóm account.

## Azure Policy có thay Microsoft Entra ID / Azure RBAC policy?

Không. Effective permission là giao của identity/resource policies, permission boundary, session policy và Azure Policy. Azure Policy không grant.

## Azure Landing Zones

Azure Landing Zones xây landing zone và guardrails trên Management Groups; vẫn cần ownership cho customization, drift, account lifecycle và exceptions.

