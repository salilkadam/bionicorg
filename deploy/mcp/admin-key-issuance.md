# MCP admin: issue/rotate a scoped key (Drive or otherwise)

The shared key at Vault `secret/t6-apps/bionic-org/config/shared-api-keys`
(`mcp_api_key`) was issued **before** the multitenant-mcp-servers gateway added
per-key scope enforcement. When a key lacks a scope a tool needs, the gateway
returns `401 Unauthorized` (not a clear scope error), which looks like a broken
deployment — it is not. Verified 2026-10-07: the old shared key returns 401 on
every gworkspace tool; a freshly issued key works; `tools/list` is scope-exempt
so it always succeeds (another confusing signal).

## Issuing a new key

Admin API is the `mcp-admin-ui` service (port 8000); the admin key is the
`MCP_ADMIN_KEY` value of the `mcp-admin-ui` secret:

```sh
ADMIN=$(kubectl -n mcp get secret mcp-admin-ui -o jsonpath='{.data.MCP_ADMIN_KEY}' | base64 -d)
kubectl -n mcp port-forward svc/mcp-admin-ui 8801:8000 &
curl -s -X POST http://127.0.0.1:8801/api/keys -H "x-admin-api-key: $ADMIN" \
  -H 'content-type: application/json' \
  -d '{"label":"paperclip-agents-drive","tenant":"base","scopes":["drive:read","drive.file"]}'
```

The response contains `key` **once** (`sk-admin-...`). Scope names come from
`GET /api/scopes`. There is no update-key scope endpoint — rotation = create
new key, move consumers, delete old key row.

## Wiring it into Paperclip agents

1. Store it in Vault: `kv put t6-apps/bionic-org/config shared-api-keys` (add a
   `mcp_agents_key` key to the existing secret — same JSON map the ESO secret
   reads).
2. ExternalSecret `shared-api-keys-template` (`deploy/vault/external-secrets.yaml`)
   references `mcp_api_key` via `extract`; add a `mcp_agents_key` entry to both
   the template data map and the `data:` list, then `kubectl -n bionicorg apply`
   and `rollout restart deploy/bionic-org`.
3. Verify from a throwaway pod (`bionicorg` namespace has network access to
   `mcp-gworkspace-server.mcp.svc.cluster.local:8015`): initialize + `tools/call
   gw_list_files` must return `success:true`.
4. `tools/call` requires the `mcp-session-id` response header from initialize
   sent back as `mcp-session-id` (Streamable HTTP). Missing it → `400
   Bad Request: Server has not received an initialize request yet` (returned as
   JSON-RPC `error`, not an MCP envelope — probe scripts must handle both).
