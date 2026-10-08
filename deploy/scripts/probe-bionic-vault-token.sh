#!/usr/bin/env bash
# Probe capabilities of the bionic app's Vault token (never prints the token).
# Since the 2026-10-07 scope-down the token is policy `bionic-org-app`
# (periodic, self-renewing on use), so `capabilities-self` is not available
# (it needs sudo); capability proofs are functional instead.
set -euo pipefail
kubectl -n bionicorg get secret bionic-org-secrets -o jsonpath='{.data.vault_token}' | base64 -d > /tmp/va.txt
chmod 600 /tmp/va.txt
kubectl -n vault cp /tmp/va.txt vault-0:/tmp/va.txt
rm -f /tmp/va.txt
kubectl -n vault exec vault-0 -- sh -c '
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(cat /tmp/va.txt)
echo "== identity =="
vault token lookup 2>&1 | grep -E "token_display_name|policies|ttl |period" | head -6
echo "== self-renew (keeps the periodic token alive) =="
vault token renew >/dev/null 2>&1 && echo "renew ok" || echo "renew FAILED"
echo "== functional: secret/t6-apps/mcp/config =="
vault kv get -format=json secret/t6-apps/mcp/config >/dev/null 2>&1 && echo "read OK" || echo "read DENIED"
echo "== functional: secret/t6-apps/bionic-org/config =="
vault kv get -format=json secret/t6-apps/bionic-org/config >/dev/null 2>&1 && echo "read OK" || echo "read DENIED"
echo "== negative control (must be denied) =="
vault kv put secret/t6-apps/probe-test x=1 >/dev/null 2>&1 && echo "UNEXPECTED: write outside scope allowed" || echo "write outside scope: DENIED (correct)"
rm -f /tmp/va.txt
'
