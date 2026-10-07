#!/usr/bin/env bash
# Probe the agent-side gworkspace path: POST /tool-connections/:id/test-calls
# runs gw_list_files through Paperclip's tool gateway using the BOUND managed
# secret (loc-gworkspace-apikey) — exactly what agent runtime would use.
set -uo pipefail
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
CONN=${1:-78ad5e0e-8c3c-43ab-af13-eff20e870998}

AGENT=$($PG -c "select id from agents where company_id::text like '62d63984%' and name ilike 'Project Manager' and status<>'paused' limit 1;")
echo "agent=$AGENT"

# build JSON payload locally (no shell-escaping games)
python3 - "$AGENT" <<'PY' > /tmp/scratchpad/tc-payload.json
import json,sys
print(json.dumps({
  "agentId": sys.argv[1],
  "toolName": "gw_list_files",
  "parameters": {"query": "'1X3mLZ0IP1pJDJtMm5WZwoAzBb_qoh5dz' in parents and trashed=false"}
}))
PY

KEY="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$KEY" | sha256sum | cut -d' ' -f1)
$PG -c "INSERT INTO board_api_keys (user_id,name,key_hash,expires_at) VALUES ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','gws-testcall','${HASH}', now()+interval '10 minutes');" >/dev/null

printf '%s' "$KEY" | kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'
kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- sh -c 'cat > /tmp/.payload' < /tmp/scratchpad/tc-payload.json

kubectl -n bionicorg exec deploy/bionic-org -c bionic -- sh -c 'T=$(cat /tmp/.bt); rm -f /tmp/.bt; curl -s -X POST http://localhost:3100/api/tool-connections/'"$CONN"'/test-calls -H "authorization: Bearer $T" -H "content-type: application/json" --data @/tmp/.payload; rm -f /tmp/.payload' 2>&1 | grep -v WANTED | head -c 1500; echo

$PG -c "DELETE FROM board_api_keys WHERE name='gws-testcall' AND created_at > now()-interval '15 minutes';" >/dev/null
echo "(board key revoked)"
