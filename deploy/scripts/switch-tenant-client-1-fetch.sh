
# Step 1 of tenant-client switch: fetch current mcp config data into a local
# 0600 file for transformation. Never prints values.
set -euo pipefail
UMASK=$(umask)
kubectl -n bionicorg get secret bionic-org-secrets -o jsonpath='{.data.vault_token}' | base64 -d > /tmp/va.txt
chmod 600 /tmp/va.txt
kubectl -n vault cp /tmp/va.txt vault-0:/tmp/va.txt
rm -f /tmp/va.txt
kubectl -n vault exec vault-0 -- sh -c '
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(cat /tmp/va.txt)
vault kv get -format=json secret/t6-apps/mcp/config > /tmp/mcp-cfg.json
rm -f /tmp/va.txt
echo "data keys:"; grep -o "\"[a-z_]*\":" /tmp/mcp-cfg.json | tr -d "\":
" | sort -u | head -12
'
kubectl -n vault cp vault-0:/tmp/mcp-cfg.json /tmp/mcp-cfg.json
chmod 600 /tmp/mcp-cfg.json
echo "saved locally: $(wc -c < /tmp/mcp-cfg.json) bytes"
