#!/usr/bin/env bash
# Get a Google consent URL from the gworkspace server for tenant "base",
# account "bionicorg", drive-only scopes (avoids restricted-scope blocks),
# via the Paperclip gateway test-call path.
set -uo pipefail
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998
mkdir -p /tmp/scratchpad

AGENT=$($PG -c "select id from agents where company_id::text like '62d63984%' and name ilike 'Project Manager' and status<>'paused' limit 1;")
echo "agent=$AGENT"

python3 - "$AGENT" <<'PY' > /tmp/scratchpad/authurl-payload.json
import json,sys
print(json.dumps({
  "agentId": sys.argv[1],
  "toolName": "gw_add_account",
  "parameters": {"tenant_id": "base", "account": "bionicorg", "scopes": ["drive"]}
}))
PY

KEY="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$KEY" | sha256sum | cut -d' ' -f1)
$PG -c "INSERT INTO board_api_keys (user_id,name,key_hash,expires_at) VALUES ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','gws-authurl','${HASH}', now()+interval '10 minutes');" >/dev/null

printf '%s' "$KEY" | kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'
kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- sh -c 'cat > /tmp/.payload' < /tmp/scratchpad/authurl-payload.json

kubectl -n bionicorg exec deploy/bionic-org -c bionic -- sh -c 'T=$(cat /tmp/.bt); rm -f /tmp/.bt; curl -s -X POST http://localhost:3100/api/tool-connections/'"$CONN"'/test-calls -H "authorization: Bearer $T" -H "content-type: application/json" --data @/tmp/.payload; rm -f /tmp/.payload' 2>&1 | grep -v WANTED | head -c 2500; echo

$PG -c "DELETE FROM board_api_keys WHERE name='gws-authurl' AND created_at > now()-interval '15 minutes';" >/dev/null
echo "(board key revoked)"
