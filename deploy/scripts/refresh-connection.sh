#!/usr/bin/env bash
# Force health-check + catalog refresh on a tool connection via board API.
set -uo pipefail
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
CONN=${1:-78ad5e0e-8c3c-43ab-af13-eff20e870998}

KEY="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$KEY" | sha256sum | cut -d' ' -f1)
$PG -c "INSERT INTO board_api_keys (user_id,name,key_hash,expires_at) VALUES ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','conn-refresh','${HASH}', now()+interval '10 minutes');" >/dev/null
printf '%s' "$KEY" | kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'

for route in health-check catalog/refresh; do
  echo "== $route =="
  kubectl -n bionicorg exec deploy/bionic-org -c bionic -- sh -c "T=\$(cat /tmp/.bt); curl -s -X POST http://localhost:3100/api/tool-connections/${CONN}/${route} -H \"authorization: Bearer \$T\" | head -c 300"; echo
done

kubectl -n bionicorg exec deploy/bionic-org -c bionic -- sh -c 'rm -f /tmp/.bt'
$PG -c "DELETE FROM board_api_keys WHERE name='conn-refresh' AND created_at > now()-interval '15 minutes';" >/dev/null
echo "(revoked)"
