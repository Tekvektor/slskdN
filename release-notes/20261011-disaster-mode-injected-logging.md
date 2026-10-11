---
category: fixed
audience: operators
area: release-pipeline
action: none
breaking: false
---
Disaster-mode subscriber failure diagnostics now use an injected logger, avoiding process-wide logger replacement in parallel tests and stabilizing release validation.
