---
category: security
audience: operators
area: ci
action: none
breaking: false
---

Public pull-request checks and manual runs outside `main` now use GitHub-hosted runners. Persistent self-hosted runners are reserved for trusted workflows, and release jobs use narrower token permissions.
