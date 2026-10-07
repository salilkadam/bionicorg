#!/usr/bin/env bash
# Compare sha256 (first 8) of claude_subscription_token across Vault, ESO-synced
# Secret, and live pod env. Prints hashes only — never the token itself.
set -uo pipefail

echo "=== 1. Vault (shared/api-keys, paperclip read-only role) ==="
kubectl -n t6-infra exec vault -- sh -c '
VT=$(vault read -format=json -field=token /tmp/vault-key --role paperclip 2>/dev/null)
[ -z "$VT" ] && VT=$(cat /tmp/vault-key.vault 2>/dev/null)
curl -s -H "X-Vault-Token: $VT" http://127.0.0.1:8200/v1/secret/data/shared/api-keys
' 2>/dev/null | python3 -c '
import sys,json,hashlib
try:
    kv=json.load(sys.stdin)["data"]["data"]
except Exception as e:
    print("vault read failed:",e); sys.exit(0)
v=kv.get("claude_subscription_token","")
print("vault sha8:", hashlib.sha256(v.encode()).hexdigest()[:8], "len:", len(v))
'

echo "=== 2. ESO-synced k8s Secret bionic-org-api-keys ==="
kubectl -n bionicorg get secret bionic-org-api-keys -o jsonpath='{.data.claude_subscription_token}' | base64 -d | sha256sum | cut -c1-8 | sed "s/^/secret sha8: /"

echo "=== 3. Live pod env ==="
kubectl -n bionicorg exec deploy/bionic-org -c bionic -- sh -c '
python3 - 2>/dev/null <<PY
import os,hashlib
def h(k):
    v=os.environ.get(k,"")
    print(k, "sha8:", hashlib.sha256(v.encode()).hexdigest()[:8] if v else "EMPTY", "len:", len(v))
h("CLAUDE_CODE_OAUTH_TOKEN")
h("claude_subscription_token")
print("ANTHROPIC_API_KEY present:", bool(os.environ.get("ANTHROPIC_API_KEY")))
PY
' 2>&1 | grep -v WANTED

echo "=== 4. ESO status ==="
kubectl -n bionicorg get externalsecret bionic-org-api-keys -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.lastTransitionTime} {.message}{"\n"}{end}' 2>/dev/null | head -5
