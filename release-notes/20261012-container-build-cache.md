---
category: changed
audience: operators
area: packaging
action: none
breaking: false
---
Container builds now reuse web assets across release version changes and keep package-version metadata outside the system-package install layer, shortening repeat builds without changing the packaged runtime.
