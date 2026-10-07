#!/usr/bin/env bash
# What did Kong see for gworkspace requests? Distinguish authenticated
# consumers from the anonymous fallback.
set -uo pipefail
KPOD=$(kubectl -n kong get pods --no-headers | awk '/kong-kong-/ {print $1; exit}')
echo "kong pod: $KPOD"

for C in proxy; do
  kubectl -n kong logs "$KPOD" -c "$C" --since=90m 2>/dev/null | grep -a "gworkspace" \
    > "/tmp/scratchpad/kong-log-$C.out" 2>/dev/null
done
cat /tmp/scratchpad/kong-log-proxy.out 2>/dev/null | tail -n 12

echo
echo "== distinct consumer/status seen on gworkspace =="
python3 - <<'PY'
import json, re, collections
path = "/tmp/scratchpad/kong-log-proxy.out"
try:
    lines = open(path, errors="replace").read().splitlines()
except FileNotFoundError:
    print("no kong log captured"); raise SystemExit(0)
c = collections.Counter()
for ln in lines:
    ln = ln.strip()
    if not ln.startswith("{"):
        c["non-json line"] += 1
        continue
    try:
        d = json.loads(ln)
    except Exception:
        c["unparsable"] += 1
        continue
    consumer = None
    if d.get("consumer"):
        consumer = (d["consumer"] or {}).get("username") or (d["consumer"] or {}).get("id")
    key = (
        d.get("route", {}).get("name") if d.get("route") else None,
        d.get("request", {}).get("uri") if d.get("request") else None,
        d.get("response", {}).get("status") if d.get("response") else None,
        consumer,
    )
    c[key] += 1
for k, n in c.most_common(20):
    print(f"  {n:>4}  {k}")
PY
