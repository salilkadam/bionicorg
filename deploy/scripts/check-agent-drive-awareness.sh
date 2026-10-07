#!/usr/bin/env bash
# Verify the Drive-awareness block is live on the Reliora role agents, via the
# same instructions-bundle API the patch script uses.
set -uo pipefail
NS=bionicorg
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"

$PG -c "select id || '|' || name from agents where company_id::text like '62d63984%' and status <> 'paused';" \
  > /tmp/scratchpad/agents-list.txt 2>&1
echo "agents to check: $(wc -l < /tmp/scratchpad/agents-list.txt)"

RAW="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$RAW" | sha256sum | cut -d' ' -f1)
$PG -c "insert into board_api_keys (user_id,name,key_hash,expires_at) values ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','tmp-gwsinstr','$HASH', now()+interval '10 minutes');" >/dev/null
POD=$(kubectl -n $NS get pods --no-headers | awk '/^bionic-org/ {print $1; exit}')
printf '%s' "$RAW" | kubectl -n $NS exec -i "$POD" -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'
kubectl -n $NS cp /tmp/scratchpad/agents-list.txt "$POD:/tmp/agents-list.txt" -c bionic 2>/dev/null
kubectl -n $NS cp deploy/scripts/check_agent_drive_awareness.py "$POD:/tmp/check_agent_drive_awareness.py" -c bionic 2>/dev/null

kubectl -n $NS exec "$POD" -c bionic -- python3 /tmp/check_agent_drive_awareness.py /tmp/agents-list.txt 2>&1
kubectl -n $NS exec "$POD" -c bionic -- sh -c 'rm -f /tmp/.bt /tmp/agents-list.txt /tmp/check_agent_drive_awareness.py'

kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "delete from board_api_keys where name='tmp-gwsinstr';" >/dev/null 2>&1
echo "(revoked)"
