---
category: security
audience: operators
area: ci-security
action: none
breaking: false
---
CI now pins third-party actions to immutable commits. Dependency scans fail on high or critical vulnerabilities; the container scan blocks high or critical findings with available fixes. Performance and load checks report failures directly instead of hiding them behind advisory success states.
