#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-vault-secrets.sh — Populate Vault with Bionic Org secrets
#
# Creates/updates the secret at t6-apps/bionic-org/config in Vault
# with all required environment variables.
#
# Usage:
#   ./deploy/scripts/setup-vault-secrets.sh \
#     --database-url "postgresql://..." \
#     --better-auth-secret "..." \
#     --session-secret "..." \
#     --keycloak-client-id "..." \
#     --keycloak-client-secret "..." \
#     [--vault-token "token"]
#
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VAULT_PATH="t6-apps/bionic-org/config"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --database-url)          DATABASE_URL="$2"; shift 2 ;;
    --better-auth-secret)    BETTER_AUTH_SECRET="$2"; shift 2 ;;
    --session-secret)        SESSION_SECRET="$2"; shift 2 ;;
    --keycloak-client-id)    KEYCLOAK_CLIENT_ID="$2"; shift 2 ;;
    --keycloak-client-secret) KEYCLOAK_CLIENT_SECRET="$2"; shift 2 ;;
    --vault-token)           VAULT_TOKEN="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Populating Vault secrets ==="
echo "  Path    : ${VAULT_PATH}"
echo ""

# Use the vault CLI or API
if command -v vault &> /dev/null; then
  VAULT_CMD="vault"
else
  # Fall back to kubectl exec into vault pod for kubectl-based access
  echo "  Note: vault CLI not found. Use the Vault UI or API directly."
  echo "  Path: ${VAULT_PATH}"
  echo "  Required keys:"
  echo "    - database_url"
  echo "    - better_auth_secret"
  echo "    - session_secret"
  echo "    - keycloak_client_id"
  echo "    - keycloak_client_secret"
  echo "    - vault_token"
  echo "    - minio_root_user"
  echo "    - minio_root_password"
  exit 0
fi

# Build JSON payload
SECRET_JSON=$(jq -n \
  --arg db "${DATABASE_URL}" \
  --arg auth "${BETTER_AUTH_SECRET}" \
  --arg sess "${SESSION_SECRET}" \
  --arg kc_id "${KEYCLOAK_CLIENT_ID}" \
  --arg kc_sec "${KEYCLOAK_CLIENT_SECRET}" \
  --arg vtok "${VAULT_TOKEN:-}" \
  --arg muser "${MINIO_ROOT_USER:-}" \
  --arg mpass "${MINIO_ROOT_PASSWORD:-}" \
  '{
    database_url: $db,
    better_auth_secret: $auth,
    session_secret: $sess,
    keycloak_client_id: $kc_id,
    keycloak_client_secret: $kc_sec,
    vault_token: $vtok,
    minio_root_user: $muser,
    minio_root_password: $mpass
  }')

echo "Writing to Vault..."
echo "${SECRET_JSON}" | ${VAULT_CMD} kv put -mount=secret "${VAULT_PATH}" -input=-

echo ""
echo "✓ Vault secrets written"
echo ""
echo "Next: Verify with:"
echo "  vault kv get ${VAULT_PATH}"
