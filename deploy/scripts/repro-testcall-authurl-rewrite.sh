#!/usr/bin/env bash
# A/B probe for the test-calls auth_url bug
# (doc/plans/2026-10-07-gws-consent-url-rewrite-bug.md):
# calls gw_add_account via BOTH the Paperclip gateway test-call path and the
# direct upstream MCP path, then decodes the OAuth state shape of each.
# On a build WITHOUT the redaction fix the gateway row shows
# "no auth_url found" (the field was blanked to ***REDACTED***).
# On a FIXED build both rows must print canonical: true with identical keys.
set -uo pipefail
NS=bionicorg
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998
PROBE_ACCT="shape-probe-$(date +%s)"
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
mkdir -p /tmp/scratchpad

AGENT=$($PG -c "select id from agents where company_id::text like '62d63984%' and name ilike 'Project Manager' limit 1;")
python3 - "$AGENT" "$PROBE_ACCT" <<'PY' > /tmp/scratchpad/shape-payload.json
import json, sys
print(json.dumps({"agentId": sys.argv[1], "toolName": "gw_add_account",
                  "parameters": {"tenant_id": "base", "account": sys.argv[2], "scopes": ["drive"]}}))
PY

RAW="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$RAW" | sha256sum | cut -d' ' -f1)
$PG -c "insert into board_api_keys (user_id,name,key_hash,expires_at) values ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','tmp-shape','$HASH', now()+interval '10 minutes');" >/dev/null
POD=$(kubectl -n $NS get pods --no-headers | awk '/^bionic-org/ {print $1; exit}')
printf '%s' "$RAW" | kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'
kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.p' < /tmp/scratchpad/shape-payload.json

echo "== gateway test-call path =="
kubectl -n $NS exec "$POD" -c bionic -- sh -c 'T=$(cat /tmp/.bt); curl -s -X POST -H "authorization: Bearer $T" -H "content-type: application/json" --data @/tmp/.p http://localhost:3100/api/tool-connections/'"$CONN"'/test-calls > /tmp/.gwres; wc -c < /tmp/.gwres' >/dev/null
kubectl -n $NS exec "$POD" -c bionic -- cat /tmp/.gwres > /tmp/scratchpad/shape-gateway.json
kubectl -n $NS exec "$POD" -c bionic -- sh -c 'rm -f /tmp/.bt /tmp/.p /tmp/.gwres'

echo "-- state shape via gateway --"
node deploy/scripts/decode-authurl-state.mjs /tmp/scratchpad/shape-gateway.json

echo "== direct upstream path =="
kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' | base64 -d > /tmp/.ak
chmod 600 /tmp/.ak
kubectl -n $NS cp /tmp/.ak "$POD:/tmp/.ak" -c bionic
kubectl -n $NS cp deploy/scripts/mint-gws-consent-url.mjs "$POD:/tmp/mint.mjs" -c bionic
rm -f /tmp/.ak
kubectl -n $NS exec "$POD" -c bionic -- sh -c 'node /tmp/mint.mjs '"$PROBE_ACCT"' > /tmp/.url; rm -f /tmp/.ak /tmp/mint.mjs'
kubectl -n $NS exec "$POD" -c bionic -- cat /tmp/.url > /tmp/scratchpad/shape-direct.txt
kubectl -n $NS exec "$POD" -c bionic -- sh -c 'rm -f /tmp/.url'
python3 -c "import json;print(json.dumps({'result':{'content':'{\"auth_url\": \"'+open('/tmp/scratchpad/shape-direct.txt').read().strip()+'\"}'}}))" > /tmp/scratchpad/shape-direct.json
echo "-- state shape direct --"
node deploy/scripts/decode-authurl-state.mjs /tmp/scratchpad/shape-direct.json

kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "delete from board_api_keys where name='tmp-shape';" >/dev/null 2>&1
echo "(revoked)"
