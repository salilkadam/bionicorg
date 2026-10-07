#!/usr/bin/env bash
# Prove the write path agents use: create a doc in the approved space, then
# delete it. Uses the account the Drive-awareness notes pin.
set -uo pipefail
NS=bionicorg
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998
AGENT=80214764-0c4d-43d5-b495-4cc8eee1b0d0
SHARED=1X3mLZ0IP1pJDJtMm5WZwoAzBb_qoh5dz

RAW="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$RAW" | sha256sum | cut -d' ' -f1)
$PG -c "insert into board_api_keys (user_id,name,key_hash,expires_at) values ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','tmp-gwswrite','$HASH', now()+interval '12 minutes');" >/dev/null
POD=$(kubectl -n $NS get pods --no-headers | awk '/^bionic-org/ {print $1; exit}')
printf '%s' "$RAW" | kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'

call() { # $1 = json payload file content
  printf '%s' "$1" | kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.p'
  kubectl -n $NS exec "$POD" -c bionic -- sh -c "T=\$(cat /tmp/.bt); curl -s -X POST -H \"authorization: Bearer \$T\" -H 'content-type: application/json' --data @/tmp/.p 'http://localhost:3100/api/tool-connections/$CONN/test-calls'; rm -f /tmp/.p"
}

PAYLOAD=$(python3 - "$AGENT" "$SHARED" <<'PY'
import json, sys
agent, shared = sys.argv[1:3]
print(json.dumps({"agentId": agent, "toolName": "gw_create_file",
                  "parameters": {"tenant_id": "base", "account": "salil-bionicaisolutions",
                                 "name": "2026-10-07-gateway-write-test.md",
                                 "content": "# Gateway write test\n\nSafe to delete.\n",
                                 "folder_id": shared}}))
PY
)
echo "== create =="
CREATE=$(call "$PAYLOAD")
echo "$CREATE" | head -c 500; echo
echo

FILE_ID=$(printf '%s' "$CREATE" | python3 -c '
import sys,json,re
raw=sys.stdin.read()
m=re.search(r"\"id\\\\\":\\\\\"([A-Za-z0-9_-]{20,})\"", raw) or re.search(r"\"fileId\\\\\":\\\\\"([A-Za-z0-9_-]{20,})", raw)
print(m.group(1) if m else "")
')
echo "created file id: ${FILE_ID:-<not parsed>}"

if [ -n "$FILE_ID" ]; then
  DEL=$(python3 - "$AGENT" "$FILE_ID" <<'PY'
import json, sys
agent, fid = sys.argv[1:3]
print(json.dumps({"agentId": agent, "toolName": "gw_delete_file",
                  "parameters": {"tenant_id": "base", "account": "salil-bionicaisolutions",
                                 "file_id": fid}}))
PY
  )
  echo "== cleanup delete =="
  call "$DEL" | head -c 300; echo
fi

kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "delete from board_api_keys where name='tmp-gwswrite';" >/dev/null 2>&1
echo "(revoked)"
