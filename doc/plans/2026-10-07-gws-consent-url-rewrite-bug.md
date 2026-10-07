### Consent URL bug found during retirement (2026-10-07)

`POST /tool-connections/:id/test-calls` for `gw_add_account` does **not**
return the server's canonical `auth_url`. The dispatched result is rewritten
with a legacy OAuth `state` (`{"tenant_id","account"}`, no `exp`/nonce) which
the gworkspace callback cannot parse (`peek["t"]` → `None` → "Tenant 'None'
not found"). The upstream server itself is clean: direct MCP calls to
`https://mcp.baisoln.com/gworkspace/mcp` (any User-Agent, internal svc or via
Kong/Cloudflare) always return the canonical `{"t","a","s","n","exp"}` state,
verified in-pod with the tenant's own `verify_state`.

Workaround in use: mint consent URLs directly from the server with
`deploy/scripts/mint-gws-consent-url.mjs` (see
`deploy/scripts/run-gws-direct-probe.sh` for how the API key is staged into
the bionic pod without printing it). Root-cause the rewrite in the deployed
Paperclip dispatch layer (image `40e3e904e`; no matching builder exists in
repo HEAD) and add a regression test that the gateway returns the upstream
`auth_url` byte-identical.
