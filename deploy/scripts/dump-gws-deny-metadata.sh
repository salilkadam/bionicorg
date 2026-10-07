#!/usr/bin/env bash
# Dump the gateway execution metadata for the most recent deny, with any value
# that looks like a credential masked.
set -uo pipefail
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A -c "
select jsonb_pretty(metadata) from tool_call_events
where decision='deny' and created_at > now() - interval '10 minutes'
order by created_at desc limit 1;" > /tmp/scratchpad/deny.json 2>&1

python3 - <<'PY'
import json, re
raw = open("/tmp/scratchpad/deny.json").read()
try:
    d = json.loads(raw)
except Exception as e:
    print("unparsable:", raw[:400]); raise SystemExit(0)

def walk(o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            walk(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, f"{path}[{i}]")
    else:
        s = str(o)
        low = path.lower()
        if any(x in low for x in ("authorization", "apikey", "api_key", "token", "secret", "bearer", "key")):
            print(f"{path}: <masked len={len(s)}>")
        else:
            print(f"{path}: {s[:300]}")
walk(d)
PY
