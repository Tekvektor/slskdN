---
category: security
audience: operators
area: ci-security
action: none
breaking: false
---
CI now pins third-party actions to immutable commits and fails security scans when high or critical vulnerabilities are found. Performance and load checks report failures directly instead of hiding them behind advisory success states.
