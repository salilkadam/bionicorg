#!/bin/bash
# Throwaway: run agents-drive-awareness.mjs with a short-lived board token.
# The token is staged into a 0600 file inside the pod, consumed, then deleted.
set -euo pipefail
HEX=$(openssl rand -hex 24)
TOK="pcp_board_${HEX}"
HASH=$(printf '%s' "$TOK" | sha256sum | cut -d' ' -f1)
kubectl exec pg-ceph-7 -n pg -c postgres -- psql -d bionicorg -c \
  "INSERT INTO board_api_keys (user_id, name, key_hash, expires_at) VALUES ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','drive-awareness-runner','${HASH}', now() + interval '20 minutes')"
printf '%s' "$TOK" | kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- \
  sh -c 'cat > /tmp/.bt && chmod 600 /tmp/.bt'
RC=0
kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- \
  sh -c 'T=$(cat /tmp/.bt); rm -f /tmp/.bt; export BIONIC_BOARD_TOKEN=$T; exec node -' \
  < deploy/scripts/agents-drive-awareness.mjs || RC=$?
kubectl exec pg-ceph-7 -n pg -c postgres -- psql -d bionicorg -c \
  "DELETE FROM board_api_keys WHERE name='drive-awareness-runner'"
exit $RC
