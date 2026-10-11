---
category: security
audience: operators
area: logging-privacy
action: none
breaking: false
---
File-operation failure logs no longer include local paths, path-derived names, or exception details that can repeat them. They retain operation context, exception type, and HRESULT, reducing disclosure of configured directory layout and private filenames.
