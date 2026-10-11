---
category: fixed
audience: users, operators
area: data-retention
action: none
breaking: false
---
Transfer batch and duplicate-file lookups now use SQLite indexes. Soft-removed completed transfers are permanently deleted after seven days by default; set `retention.transfers.removed: null` to keep them indefinitely. Events are capped at 10,000 records and searches at 250 by default, alongside age retention; set either count to `0` for no count limit.
