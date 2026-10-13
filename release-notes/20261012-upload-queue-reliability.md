---
category: fixed
audience: users, operators
area: upload-queue
action: none
breaking: false
---
Queued uploads now honor cancellation promptly and release capacity only for the matching transfer. Queue estimates account for global slot capacity, and retry actions are limited to downloads.
