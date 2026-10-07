
# Probe capabilities of the bionic app's Vault token (never prints the token).
set -euo pipefail
kubectl -n bionicorg get secret bionic-org-secrets -o jsonpath='{.data.vault_token}' | base64 -d > /tmp/va.txt
kubectl -n vault cp /tmp/va.txt vault-0:/tmp/va.txt
rm -f /tmp/va.txt
kubectl -n vault exec vault-0 -- sh -c '
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(cat /tmp/va.txt)
echo "== identity =="
vault token lookup 2>&1 | grep -E "token_name|policies|ttl " | head -6
echo "== capabilities: secret/t6-apps/mcp/config =="
vault token capabilities secret/t6-apps/mcp/config 2>&1
echo "== capabilities: secret/t6-apps/bionic-org/config =="
vault token capabilities secret/t6-apps/bionic-org/config 2>&1
rm -f /tmp/va.txt
'
