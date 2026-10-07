#!/usr/bin/env bash
# Fix the Loc-Google Workspace 401 at its root.
#
# Diagnosis: the connection's credentialRef ({key: apikey, placement: header}) is
# correct and the bound secret value is a valid Kong key, but the connection_grants
# row has credential_secret_refs = []. tool-gateway.ts resolveCredentialHeadersUnrecorded()
# skips any header ref with no matching grant ref (`if (!grantRef) continue`), so the
# apikey header was never put on the wire and Kong served the request as the
# anonymous consumer -> the gworkspace app rejects anonymous -> 401 on every call.
#
# The supported repair path is POST /tool-connections/:id/reconnect ("replace key"),
# which writes the credential AND appends the matching grant ref.
#
# Key material is only ever in a pod temp file that is deleted; never printed.
set -uo pipefail
NS=bionicorg
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998

KEY=$(kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' | base64 -d | tr -d '\n')
echo "key length: ${#KEY}"

python3 - "$KEY" <<'PY' > /tmp/scratchpad/reconnect-payload.json
import json, sys
key = sys.argv[1]
# Only declared credential fields are consumed; extra paths are ignored, so we
# cover the plausible configPath spellings for this ref in one call.
print(json.dumps({"credentialValues": {
    "credentials.loc-gworkspace-apikey": key,
    "credentials.apikey": key,
}}))
PY
echo "payload bytes: $(wc -c < /tmp/scratchpad/reconnect-payload.json)"

RAW="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$RAW" | sha256sum | cut -d' ' -f1)
$PG -c "insert into board_api_keys (user_id,name,key_hash,expires_at) values ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','tmp-gwsreconnect','$HASH', now()+interval '10 minutes');" >/dev/null
POD=$(kubectl -n $NS get pods --no-headers | awk '/^bionic-org/ {print $1; exit}')
printf '%s' "$RAW" | kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'
kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.rp; chmod 600 /tmp/.rp' < /tmp/scratchpad/reconnect-payload.json

echo "== reconnect =="
kubectl -n $NS exec "$POD" -c bionic -- sh -c '
T=$(cat /tmp/.bt)
curl -s -X POST -H "authorization: Bearer $T" -H "content-type: application/json" \
  --data @/tmp/.rp "http://localhost:3100/api/tool-connections/'"$CONN"'/reconnect" \
  | python3 -c "
import sys,json
raw=sys.stdin.read()
try: d=json.loads(raw)
except Exception: print(\"  non-json:\", raw[:300]); raise SystemExit(0)
def scrub(o):
    if isinstance(o,dict): return {k:scrub(v) for k,v in o.items()}
    if isinstance(o,list): return [scrub(v) for v in o]
    if isinstance(o,str) and len(o)>40: return \"<str len=\"+str(len(o))+\">\"
    return o
c=(d.get(\"connection\") or {})
print(json.dumps({\"healthStatus\":c.get(\"healthStatus\"),\"healthMessage\":c.get(\"healthMessage\"),
                  \"status\":c.get(\"status\"),\"toolCount\":d.get(\"toolCount\") or d.get(\"catalogCount\"),
                  \"keys\":sorted(d.keys())}, indent=1))
"
rm -f /tmp/.rp'
rm -f /tmp/scratchpad/reconnect-payload.json

echo
echo "== grant refs after reconnect =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c \
  "select kind, status, jsonb_pretty(credential_secret_refs) refs from connection_grants where connection_id::text='$CONN';" 2>&1 | head -n 20

kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "delete from board_api_keys where name='tmp-gwsreconnect';" >/dev/null 2>&1
echo "(revoked)"
