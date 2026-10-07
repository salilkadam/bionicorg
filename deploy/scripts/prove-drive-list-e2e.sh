#!/usr/bin/env bash
# End-to-end proof of the Drive path through Paperclip's tool gateway, using the
# arguments gw_list_files actually requires (tenant_id + account).
set -uo pipefail
NS=bionicorg
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998
AGENT=80214764-0c4d-43d5-b495-4cc8eee1b0d0
ROOT=1MmJAx3Rkag90KSSlFISiVvkuWwvO38dK

RAW="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$RAW" | sha256sum | cut -d' ' -f1)
$PG -c "insert into board_api_keys (user_id,name,key_hash,expires_at) values ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','tmp-gwse2e','$HASH', now()+interval '12 minutes');" >/dev/null
POD=$(kubectl -n $NS get pods --no-headers | awk '/^bionic-org/ {print $1; exit}')
printf '%s' "$RAW" | kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'

for ACCT in salil-bionicaisolutions salil-bionicaisol salil-personal-gmail; do
  python3 - "$AGENT" "$ACCT" "$ROOT" <<'PY' > /tmp/scratchpad/e2e.json
import json, sys
agent, acct, root = sys.argv[1:4]
print(json.dumps({"agentId": agent, "toolName": "gw_list_files",
                  "parameters": {"tenant_id": "base", "account": acct,
                                 "query": f"'{root}' in parents and trashed=false"}}))
PY
  kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.p' < /tmp/scratchpad/e2e.json
  printf '%-26s -> ' "$ACCT"
  kubectl -n $NS exec "$POD" -c bionic -- sh -c "T=\$(cat /tmp/.bt); curl -s -X POST -H \"authorization: Bearer \$T\" -H 'content-type: application/json' --data @/tmp/.p 'http://localhost:3100/api/tool-connections/$CONN/test-calls' | head -c 420; echo"
done
kubectl -n $NS exec "$POD" -c bionic -- sh -c 'rm -f /tmp/.p'
rm -f /tmp/scratchpad/e2e.json
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "delete from board_api_keys where name='tmp-gwse2e';" >/dev/null 2>&1
echo "(revoked)"
