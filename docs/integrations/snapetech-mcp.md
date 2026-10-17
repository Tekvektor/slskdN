# SnapeTech MCP

slskdN does not run a Model Context Protocol server in its application
runtime. Its `MCP-HARDENING.md` uses **MCP** to mean Moderation / Control Plane;
that feature remains separate. The shared `snapetech-mcp` process calls
slskdN's existing API over MCP stdio transport. Its quickstart is in the sibling
`snapetech-mcp/README.md`.

## Tools and API access

| MCP tool | slskdN endpoint | Result |
| --- | --- | --- |
| `slskdn_status` | `GET /health` | Reachability only. |
| `slskdn_get_swarm_performance` | `GET /api/v0/swarm/analytics/performance` | Aggregate performance for a bounded time window; requires multi-source downloads to be enabled. |
| `slskdn_list_downloads` | `GET /api/v0/downloads/requests` | Download state and attempt counts, optionally filtered by state. |

Configure `SNAPETECH_MCP_APPS=slskdn`,
`SNAPETECH_MCP_SLSKDN_URL=<slskdN base URL>`, and
`SNAPETECH_MCP_SLSKDN_API_KEY=<dedicated API key>` in the MCP host's protected
environment. The bridge sends the key in `X-Api-Key`.

## Credential and data boundaries

Use an API key with the **ReadOnly** role. The current request-list endpoint
does not declare an explicit API-key scope mapping, so a custom non-wildcard
scope may be denied by the global deny-by-default filter. A ReadOnly key with
the endpoint's supported default scope works, and its role blocks writes; it
may still read other endpoints allowed to that role. Do not use ReadWrite or
Administrator credentials.

The request-list endpoint returns an unpaged collection. The MCP adapter
projects only state and attempt counts and caps response processing, but
slskdN still performs the underlying list query. It discards request names,
filenames, full paths, peer identities, and hashes.

Keep the MCP process attached to a trusted local client. Prefer HTTPS for
remote instances; never expose the stdio server through a TCP bridge or reverse
proxy. This integration does not alter slskdN's Moderation / Control Plane.

## Competitor feature coverage

The slskd lineage covers search, shares and peer browsing, transfer queues,
events/webhooks, metrics, and retention. slskdN also maintains an [experimental
feature inventory](../../FEATURE_INVENTORY.md) for its extensions. The official
[slskd configuration guide](https://github.com/slskd/slskd/blob/master/docs/config.md)
documents share scanning, search throttling, event integrations, and
transfer/search retention.

Snapetech MCP reports request states/attempt counts and aggregate swarm performance.
The performance tool is unavailable when multi-source downloads are disabled. The
request-list route remains unpaged, so the bridge's response and output caps do not
bound the work slskdN performs. Search, browse, download, and management actions have
peer-network effects or expose peer/file data and remain outside this adapter pending a
separate route-scope and side-effect review.

**Confidence:** high for the documented product/API surface and current route contract; moderate for direct feature comparison because several slskdN extensions are experimental.

Source contract: `docs/MCP-HARDENING.md`,
`src/slskd/Transfers/Downloads/API/DownloadRequestsController.cs`, and
`src/slskd/Common/Authentication/ScopedApiKeyDenyByDefaultFilter.cs`.
