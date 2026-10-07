
echo "=== ESO controller pod + vault token mount ==="
ESO_POD=$(kubectl -n external-secrets get pods --no-headers 2>/dev/null | awk '/external-secrets/ && !/webhook/ {print $1; exit}')
echo "eso pod: $ESO_POD"
kubectl -n external-secrets get deploy external-secrets -o jsonpath='{range .spec.template.spec.volumes[*]}{.name}{" -> "}{.secret.secretName}{"\n"}{end}' 2>/dev/null
echo "=== secret with vault token ==="
kubectl -n external-secrets get secret vault-token-store -o jsonpath='{.data}' 2>/dev/null | tr ',' '\n' | sed 's/[{"]//g' | cut -d: -f1 || echo "no vault-token-store secret"
echo "=== capabilities of that token (read-only introspection) ==="
kubectl -n external-secrets get secret vault-token-store -o jsonpath='{.data.vault-token}' 2>/dev/null | base64 -d > /tmp/vt.txt 2>/dev/null && echo "token file created"
if [ -s /tmp/vt.txt ]; then
  kubectl -n vault cp /tmp/vt.txt vault-0:/tmp/vt.txt
  kubectl -n vault exec vault-0 -- sh -c 'VAULT_TOKEN=$(cat /tmp/vt.txt) VAULT_ADDR=http://127.0.0.1:8200 vault token capabilities list 2>/dev/null | grep -E "t6-apps|PATH" | head -5; echo ---; VAULT_TOKEN=$(cat /tmp/vt.txt) VAULT_ADDR=http://127.0.0.1:8200 vault token capabilities secret/t6-apps/mcp/config 2>/dev/null; rm -f /tmp/vt.txt'
  rm -f /tmp/vt.txt
fi
