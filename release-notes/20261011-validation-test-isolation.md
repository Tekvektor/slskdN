---
category: fixed
audience: operators
area: release-pipeline
action: none
breaking: false
---
Hosted validation contract tests no longer capture process-global output while sibling tests run, preventing concurrent-test interference from causing false release-gate failures.
