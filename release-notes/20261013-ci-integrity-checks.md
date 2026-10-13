---
category: security
audience: operators
area: ci-security
action: none
breaking: false
---
GitHub now requires CI actions to use full immutable commit pins. Dependency scans fail on high or critical vulnerabilities; the container scan blocks high or critical findings with available fixes. Performance and load checks report failures directly instead of hiding them behind advisory success states. Maintainers can retry selected publishers for an existing stable release using its published assets, without rebuilding binaries or repeating successful publishers and announcements.
