#!/usr/bin/env bash
# Show the *shape* of the gworkspace accounts hash for tenant `base`:
# how many Google accounts are stored and when each was last refreshed.
# Field VALUES are never printed (they contain OAuth tokens).
set -uo pipefail
P=$(kubectl -n mcp get pods --no-headers | awk '/mcp-gworkspace-server/ {print $1; exit}')

kubectl -n mcp exec -i "$P" -c gworkspace -- python3 - > /tmp/scratchpad/gws-accounts.out 2>&1 <<'PY'
import os, json, redis
h = os.environ.get("REDIS_HOST") or "redis"
db = int(os.environ.get("REDIS_DB") or 0)
r = redis.Redis(host=h, port=int(os.environ.get("REDIS_PORT") or 6379), db=db, decode_responses=True)
key = "mcp:gworkspace:accounts:base"
if not r.exists(key):
    print("no accounts hash for tenant base -> NO Google account is connected")
    raise SystemExit(0)
fields = r.hkeys(key)
print("accounts stored for tenant 'base':", len(fields))
for f in fields:
    raw = r.hget(key, f)
    try:
        d = json.loads(raw)
    except Exception:
        print("  account:", f, "| unparsable"); continue
    if isinstance(d, dict):
        print("  account:", f)
        for k in sorted(d):
            low = k.lower()
            if any(s in low for s in ("token", "secret", "refresh", "access", "id_token")):
                v = d.get(k)
                print(f"     {k}: <present, {len(str(v))} chars>" if v else f"     {k}: <empty>")
            else:
                print(f"     {k}: {d.get(k)}")
PY
cat /tmp/scratchpad/gws-accounts.out
