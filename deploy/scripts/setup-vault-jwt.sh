#!/usr/bin/env bash
# setup-vault-jwt.sh — one-time Vault-side setup so External Secrets Operator
# authenticates via the Vault JWT method instead of Kubernetes service-account
# auth.
#
# What it does (idempotent):
#   1. Enables auth/jwt on Vault.
#   2. Pins the current cluster OIDC signing keys (fetched via
#      `kubectl get --raw /openid/v1/jwks`, converted to SPKI PEM with node).
#      k3s regenerates its OIDC signing key when the API server is
#      reinitialized, so re-run this script after such an event.
#   3. Creates/updates role "eso-reader": issues Vault service tokens with the
#      org ESO policy. By default the role is NOT bound to a specific service
#      account: the ClusterSecretStore is instance-shared and ESO mints its
#      login JWT from the *ESO controller's* SA (external-secrets ns), not the
#      app SA. Use --bind-sa name/ns to restrict if you use a dedicated store.
#
# After this, the ClusterSecretStore (helm template clustersecretstore.yaml)
# uses auth type jwt with kubernetesServiceAccountToken — ESO mints short-lived
# SA JWTs via the TokenRequest API and re-logs into Vault automatically. No
# service-account token is mounted into any pod and no long-lived Vault token
# is stored anywhere.
#
# NOTE on KV_PATHS: these are Vault POLICY paths on the KV v2 *mount* (this
# cluster mounts KV v2 at `secret`, not `kv`). ESO reads build as
# `<mount>/data/<key>`, and KV v2 reads also need `<mount>/metadata/<key>`.
# Wrong mount names here create a policy that silently grants nothing and every
# ExternalSecret sync 403s (Ready stays False while the K8s secret keeps
# serving STALE data — ESO sync failure is otherwise invisible in pod logs).
#
# NOTE on shared stores: the instance ClusterSecretStore (`vault-backend`) is
# used by every tenant namespace. Its Vault token only carries THIS policy, so
# the policy must list every KV path any tenant's ExternalSecret reads
# (e.g. other tenants' t6-apps/<org>/config), or those tenants 403 too.
#
# Usage:
#   VAULT_TOKEN=<admin token> ./deploy/scripts/setup-vault-jwt.sh \
#       [--vault-addr http://vault.vault.svc.cluster.local:8200] \
#       [--role eso-reader] [--policy eso-bionic-org-policy] \
#       [--bind-sa <name> <namespace>] \
#       [--kv-paths "secret/data/t6-apps/bionic-org/config secret/data/shared/api-keys secret/metadata/t6-apps/bionic-org/config secret/metadata/shared/api-keys"]
#
# Requirements: kubectl (cluster admin), node (for JWK->PEM conversion).
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://vault.vault.svc.cluster.local:8200}"
ROLE="eso-reader"
POLICY="eso-bionic-org-policy"
# Default: no SA binding (shared instance store; ESO authenticates with its own
# controller SA). Set both to pin the role to one service account.
SA_NAME=""
SA_NAMESPACE=""
KV_PATHS="secret/data/t6-apps/bionic-org/config secret/data/shared/api-keys secret/metadata/t6-apps/bionic-org/config secret/metadata/shared/api-keys"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault-addr) VAULT_ADDR="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --policy) POLICY="$2"; shift 2 ;;
    --bind-sa) SA_NAME="$2"; SA_NAMESPACE="$3"; shift 3 ;;
    --kv-paths) KV_PATHS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${VAULT_TOKEN:?VAULT_TOKEN (admin token) is required}"

# --- local preparation -------------------------------------------------------
echo "==> Fetching cluster OIDC JWKS and converting keys to SPKI PEM"
kubectl get --raw /openid/v1/jwks > "$WORKDIR/jwks.json"
node -e '
const fs=require("fs");const {createPublicKey}=require("crypto");
const jwks=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
fs.writeFileSync(process.argv[2], JSON.stringify(jwks.keys.map(k=>createPublicKey({key:k,format:"jwk"}).export({type:"spki",format:"pem"}).toString().trim())));
' "$WORKDIR/jwks.json" "$WORKDIR/pubkeys.json"

{
  for p in $KV_PATHS; do
    printf 'paths "%s" { capabilities = ["read","list"] }\n' "$p"
  done
} > "$WORKDIR/policy.hcl"

kubectl create configmap vault-jwt-setup -n vault \
  --from-file=pubkeys.json="$WORKDIR/pubkeys.json" \
  --from-file=policy.hcl="$WORKDIR/policy.hcl" \
  --dry-run=client -o yaml | kubectl apply -f -

# --- one privileged pod does all Vault writes --------------------------------
echo "==> Enabling jwt auth, pinning OIDC keys, writing policy and role"
kubectl run vault-jwt-setup -n vault --rm -i --restart=Never \
  --image=hashicorp/vault:1.20.3 --env="VAULT_TOKEN=$VAULT_TOKEN" \
  --overrides="{\"spec\":{\"containers\":[{\"name\":\"vault-jwt-setup\",\"image\":\"hashicorp/vault:1.20.3\",\"command\":[\"sh\",\"-c\",\"sleep 300\"],\"volumeMounts\":[{\"name\":\"cm\",\"mountPath\":\"/setup\",\"readOnly\":true}]}],\"volumes\":[{\"name\":\"cm\",\"configMap\":{\"name\":\"vault-jwt-setup\"}}]}}" &
SETUP_POD=vault-jwt-setup

for i in $(seq 1 30); do
  kubectl exec "$SETUP_POD" -n vault -- true 2>/dev/null && break
  sleep 2
done

kubectl exec "$SETUP_POD" -n vault -- sh -c "
  export VAULT_ADDR=$VAULT_ADDR VAULT_TOKEN=\$VAULT_TOKEN
  vault auth enable jwt 2>&1 | tail -1
  vault write auth/jwt/config jwt_validation_pubkeys=\"\$(cat /setup/pubkeys.json)\" 2>&1 | tail -1
  vault policy write $POLICY /setup/policy.hcl 2>&1 | tail -1
  vault write auth/jwt/role/$ROLE role_type=jwt user_claim=sub \
    bound_audiences=vault \
    $([ -n \"$SA_NAME\" ] && printf 'bound_service_account_names=%s bound_service_account_namespaces=%s ' \"$SA_NAME\" \"$SA_NAMESPACE\") \
    token_policies=$POLICY token_type=service token_num_uses=0 2>&1 | tail -1
"

kubectl delete pod "$SETUP_POD" -n vault --grace-period=0 --wait=false >/dev/null 2>&1 || true
kubectl delete configmap vault-jwt-setup -n vault >/dev/null 2>&1 || true

echo "Done. ClusterSecretStore (auth type jwt, role $ROLE) should validate."
echo "Note: k3s OIDC keys rotate only on API-server reinit; re-run this script then."
