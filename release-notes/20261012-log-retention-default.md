---
category: changed
audience: operators
area: logging
action: set retention.logs to 2 or greater
breaking: true
---
Default application log retention is now 14 days and the minimum is 2 days. Operators configured with 1 day must increase retention.logs to at least 2.
