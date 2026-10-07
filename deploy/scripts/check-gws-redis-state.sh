#!/usr/bin/env bash
# List what the gworkspace MCP server has stored (tenant registrations and
# Google account/credential keys) WITHOUT printing any secret material.
set -uo pipefail
P=$(kubectl -n mcp get pods --no-headers | awk '/mcp-gworkspace-server/ {print $1; exit}')

kubectl -n mcp exec -i "$P" -c gworkspace -- python3 - > /tmp/scratchpad/gws-redis-keys.out 2>&1 <<'PY'
import os, redis
h = os.environ.get("REDIS_HOST") or "redis"
db = int(os.environ.get("REDIS_DB") or 0)
try:
    r = redis.Redis(host=h, port=int(os.environ.get("REDIS_PORT") or 6379), db=db, decode_responses=True)
    r.ping()
except Exception as e:
    print("redis unreachable:", type(e).__name__, e); raise SystemExit(0)

keys = r.scan_iter(count=500)
allk = list(keys)
print("total keys in db", db, ":", len(allk))
prefixes = {}
for k in allk:
    prefixes.setdefault(k.split(":")[0], 0)
    prefixes[k.split(":")[0]] += 1
print("prefix histogram:", prefixes)

# Show only key NAMES (never values) for gworkspace-ish keys.
interesting = [k for k in allk if "gws" in k.lower() or "google" in k.lower() or "tenant" in k.lower() or "account" in k.lower()]
for k in sorted(interesting)[:60]:
    print(" key:", k, "|", r.type(k))
PY
cat /tmp/scratchpad/gws-redis-keys.out
