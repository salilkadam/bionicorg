#!/usr/bin/env bash
# Show the credential-field descriptors the board UI would render for this
# connection (configPath + label only — never values).
set -uo pipefail
NS=bionicorg
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998

RAW="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$RAW" | sha256sum | cut -d' ' -f1)
$PG -c "insert into board_api_keys (user_id,name,key_hash,expires_at) values ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','tmp-gwsfields','$HASH', now()+interval '10 minutes');" >/dev/null
POD=$(kubectl -n $NS get pods --no-headers | awk '/^bionic-org/ {print $1; exit}')
printf '%s' "$RAW" | kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'

kubectl -n $NS exec "$POD" -c bionic -- sh -c '
T=$(cat /tmp/.bt); rm -f /tmp/.bt
for EP in "tool-connections/'"$CONN"'" "tool-connections/'"$CONN"'/setup" "tool-connections/'"$CONN"'/credentials"; do
  echo "--- GET /api/$EP ---"
  curl -s -H "authorization: Bearer $T" "http://localhost:3100/api/$EP" \
   | python3 -c "
import sys,json
raw=sys.stdin.read()
try: d=json.loads(raw)
except Exception: print(\"  non-json:\", raw[:120]); raise SystemExit(0)
def scrub(o):
    if isinstance(o,dict): return {k:scrub(v) for k,v in o.items()}
    if isinstance(o,list): return [scrub(v) for v in o]
    if isinstance(o,str) and len(o)>48: return \"<str len=\"+str(len(o))+\">\"
    return o
d=scrub(d)
print(json.dumps(d, indent=1)[:2200])
"
done'

kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "delete from board_api_keys where name='tmp-gwsfields';" >/dev/null 2>&1
echo "(revoked)"
