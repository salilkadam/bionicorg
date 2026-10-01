#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-keycloak.sh — Create a Keycloak client for Bionic Org
#
# Uses the Keycloak Admin REST API to create a client for org.baisoln.com
#
# Usage:
#   ./deploy/scripts/setup-keycloak.sh \
#     --admin-user admin \
#     --admin-password admin \
#     --realm Bionic
#
# Or use the Keycloak admin console at:
#   https://auth.bionicaisolutions.com
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

KC_URL="https://auth.bionicaisolutions.com"
REALM="Bionic"
CLIENT_ID="bionic-org"
REDIRECT_URI="https://org.baisoln.com/api/auth/callback"
CLIENT_NAME="Bionic Org"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --kc-url)      KC_URL="$2"; shift 2 ;;
    --realm)       REALM="$2"; shift 2 ;;
    --client-id)   CLIENT_ID="$2"; shift 2 ;;
    --redirect)    REDIRECT_URI="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Setting up Keycloak client ==="
echo "  Realm      : ${REALM}"
echo "  Client ID  : ${CLIENT_ID}"
echo "  Redirect   : ${REDIRECT_URI}"
echo "  Console    : ${KC_URL}/admin/${REALM}/#/clients"
echo ""

# Determine admin token (try KC_TOKEN env var first, then ask for credentials)
if [[ -n "${KC_TOKEN:-}" ]]; then
  ADMIN_TOKEN="${KC_TOKEN}"
elif [[ -n "${KC_ADMIN_USER:-}" && -n "${KC_ADMIN_PASSWORD:-}" ]]; then
  echo "Fetching admin token..."
  ADMIN_TOKEN=$(curl -s "${KC_URL}/realms/master/protocol/openid-connect/token" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${KC_ADMIN_USER}" \
    -d "password=${KC_ADMIN_PASSWORD}" \
    | jq -r '.access_token')
else
  echo "No admin credentials provided."
  echo ""
  echo "You have two options:"
  echo ""
  echo "  1. Set environment variables:"
  echo "     export KC_ADMIN_USER=admin"
  echo "     export KC_ADMIN_PASSWORD=<your-password>"
  echo "     export KC_TOKEN=\$(...)"
  echo ""
  echo "  2. Create manually in the admin console:"
  echo "     ${KC_URL}/admin/${REALM}/#/clients"
  echo ""
  echo "  Client settings:"
  echo "    Client ID     : ${CLIENT_ID}"
  echo "    Client Type   : OpenID Connect"
  echo "    Root URL      : https://org.baisoln.com"
  echo "    Redirect URI  : ${REDIRECT_URI}"
  echo "    Valid URIs    : ${REDIRECT_URI}, https://org.baisoln.com/*"
  echo "    Web Origins   : +"
  echo "    Access Type   : confidential"
  echo "    Standard Flow : ON"
  echo "    Direct Access : OFF"
  echo ""
  echo "After creating the client:"
  echo "  1. Copy the Client Secret"
  echo "  2. Store it in Vault: t6-apps/bionic-org/config/keycloak_client_secret"
  echo "  3. Store the Client ID in: t6-apps/bionic-org/config/keycloak_client_id"
  exit 0
fi

# Get realm admin client secret
echo "Finding realm admin client..."
REALM_CLIENT_ID=$(curl -s "${KC_URL}/admin/realms/${REALM}/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq -r '.[] | select(.clientId=="admin-cli") | .id')

if [[ -z "${REALM_CLIENT_ID}" ]]; then
  echo "Could not find admin-cli client. Trying to use realm management..."
  exit 1
fi

# Create client
echo "Creating client ${CLIENT_ID}..."
CLIENT_RESPONSE=$(curl -s "${KC_URL}/admin/realms/${REALM}/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"${CLIENT_ID}\",
    \"name\": \"${CLIENT_NAME}\",
    \"enabled\": true,
    \"standardFlowEnabled\": true,
    \"directAccessGrantsEnabled\": false,
    \"implicitFlowEnabled\": false,
    \"serviceAccountsEnabled\": false,
    \"publicClient\": false,
    \"rootUrl\": \"https://org.baisoln.com\",
    \"redirectUris\": [\"${REDIRECT_URI}\", \"https://org.baisoln.com/*\"],
    \"webOrigins\": [\"+\"],
    \"protocol\": \"openid-connect\"
  }")

CLIENT_SECRET=$(echo "${CLIENT_RESPONSE}" | jq -r '.id')

echo ""
echo "Client created: ${CLIENT_SECRET}"
echo ""
echo "Now get the client secret:"
GET_SECRET_URL="${KC_URL}/admin/realms/${REALM}/clients/\$(curl -s \"${KC_URL}/admin/realms/${REALM}/clients\" -H \"Authorization: Bearer ${ADMIN_TOKEN}\" | jq -r '.[] | select(.clientId==\"${CLIENT_ID}\") | .id')/client-secret"

echo ""
echo "Store in Vault:"
echo "  keycloak_client_id:    ${CLIENT_ID}"
echo "  keycloak_client_secret: <from console>"
