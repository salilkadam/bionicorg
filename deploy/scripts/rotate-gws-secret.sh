#!/usr/bin/env bash
# Rotate the Paperclip managed secret bound to Loc-Google Workspace
# (loc-gworkspace-apikey, secret 23477d30) from the pod's ESO-synced
# `mcp_api_key` env — the same scoped key proven live against gworkspace.
# Uses POST /api/secrets/:id/rotate (creates a new secret version; connection
# credentialRefs keep pointing at the same secret id, so nothing else changes).
# Never prints the secret; logs sha256 first-8 before/after.
set -uo pipefail
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A"
SECRET_ID=${1:-23477d30-fe87-4070-bb1a-e9409a778fb9}

KEY="pcp_board_$(openssl rand -hex 24)"
HASH=$(printf '%s' "$KEY" | sha256sum | cut -d' ' -f1)
$PG -c "INSERT INTO board_api_keys (user_id,name,key_hash,expires_at) VALUES ('mO44P6K9aWIwqI1BGM9v3XOvkpDwWTXy','gws-rotate','${HASH}', now()+interval '10 minutes');" >/dev/null
printf '%s' "$KEY" | kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- sh -c 'cat > /tmp/.bt; chmod 600 /tmp/.bt'

kubectl -n bionicorg exec deploy/bionic-org -c bionic -- sh -c "T=\$(cat /tmp/.bt); rm -f /tmp/.bt; export BIONIC_BOARD_TOKEN=\$T; SECRET_ID=${SECRET_ID} node -e '
const crypto = require(\"crypto\");
const src = process.env.mcp_api_key || \"\";
if (!src) { console.error(\"mcp_api_key env missing\"); process.exit(1); }
console.log(\"new key sha8:\", crypto.createHash(\"sha256\").update(src).digest(\"hex\").slice(0,8), \"len:\", src.length);
(async () => {
  const r = await fetch(\"http://localhost:3100/api/secrets/\"+process.env.SECRET_ID+\"/rotate\", {
    method: \"POST\",
    headers: { authorization: \"Bearer \"+process.env.BIONIC_BOARD_TOKEN, \"content-type\": \"application/json\" },
    body: JSON.stringify({ value: src }),
  });
  const j = await r.json().catch(() => ({}));
  console.log(\"rotate http:\", r.status, \"latestVersion:\", j.latestVersion ?? JSON.stringify(j).slice(0,140));
})().catch(e => { console.error(\"ERR\", e.message); process.exit(1); });
'" 2>&1 | grep -v WANTED

$PG -c "DELETE FROM board_api_keys WHERE name='gws-rotate' AND created_at > now()-interval '15 minutes';" >/dev/null
echo "(board key revoked)"
echo "next: bash deploy/scripts/probe-gws-testcall.sh"
