#!/usr/bin/env bash
# Report which Google OAuth client the LIVE gworkspace MCP server is configured
# with, versus what the new GOOGLE_AUTH_TOKEN in bionic-org points at.
# Never prints secret values (sha256 prefix only). Client IDs are public.
set -uo pipefail

dump() { # $1 = file
python3 - "$1" <<'PY'
import json, hashlib, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("  unreadable:", type(e).__name__); raise SystemExit(0)
if isinstance(d, dict) and "tenants" in d:
    d = d["tenants"]
if not isinstance(d, dict):
    print("  unexpected shape:", type(d).__name__); raise SystemExit(0)
for tid, t in d.items():
    if not isinstance(t, dict):
        print(f"  tenant {tid}: (scalar)"); continue
    cs = str(t.get("client_secret") or "")
    h = hashlib.sha256(cs.encode()).hexdigest()[:8] if cs else "none"
    print(f"  tenant {tid}:")
    print(f"    client_id    : {t.get('client_id')}")
    print(f"    secret_sha8  : {h}")
    print(f"    redirect_uri : {t.get('redirect_uri')}")
PY
}

echo "== bionic-org pod GOOGLE_AUTH_TOKEN (Vault: t6-apps/bionic-org/config) =="
kubectl -n bionicorg exec deploy/bionic-org -c bionic -- printenv GOOGLE_AUTH_TOKEN 2>/dev/null > /tmp/scratchpad/gat.raw || true
if [ ! -s /tmp/scratchpad/gat.raw ]; then echo "  (missing)"; else
  sha256sum /tmp/scratchpad/gat.raw | cut -c1-8 | sed 's/^/  env sha8: /'
  python3 - <<'PY'
import json
raw = open("/tmp/scratchpad/gat.raw").read().strip()
try:
    w = json.loads(raw).get("web") or {}
except Exception:
    print("  NOT JSON"); raise SystemExit(0)
print("  client_id    :", w.get("client_id"))
print("  redirect_uris:", w.get("redirect_uris"))
PY
fi

echo
echo "== gworkspace server pod =="
MCP_POD=$(kubectl -n mcp get pods --no-headers 2>/dev/null | awk '/mcp-gworkspace-server/ {print $1; exit}')
echo "  pod: ${MCP_POD:-<none>}"
if [ -n "${MCP_POD:-}" ]; then
  kubectl -n mcp get pod "$MCP_POD" -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' > /tmp/scratchpad/gws-containers.out 2>/dev/null
  echo "  containers: $(tr '\n' ' ' < /tmp/scratchpad/gws-containers.out)"
  kubectl -n mcp exec "$MCP_POD" -c mcp-gworkspace -- cat /etc/mcp/tenants.json > /tmp/scratchpad/live-tenants.json 2>/dev/null || true
  if [ -s /tmp/scratchpad/live-tenants.json ]; then echo "  MOUNTED /etc/mcp/tenants.json:"; dump /tmp/scratchpad/live-tenants.json; else echo "  (could not read mounted tenants.json)"; fi
  echo "  Redis-backed tenants (runtime source of truth, if any):"
  kubectl -n mcp exec "$MCP_POD" -c mcp-gworkspace -- python3 - <<'PY' > /tmp/scratchpad/gws-redis.out 2>&1 || true
import json, hashlib, os
# Only probe what the server itself would read; do not import server modules.
print("  env REDIS_URL set:", bool(os.environ.get("REDIS_URL") or os.environ.get("REDIS_URI")))
print("  env MCP_TENANTS_FILE:", os.environ.get("MCP_TENANTS_FILE"))
PY
  cat /tmp/scratchpad/gws-redis.out 2>/dev/null || true
fi

echo
echo "== K8s Secret mcp-gworkspace-tenants (what ESO wrote from Vault t6-apps/mcp/config) =="
kubectl -n mcp get secret mcp-gworkspace-tenants -o jsonpath='{.data.tenants\.json}' 2>/dev/null | base64 -d > /tmp/scratchpad/eso-tenants.json || true
dump /tmp/scratchpad/eso-tenants.json
