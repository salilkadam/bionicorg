#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-postgres.sh — Create a new database and user in the CNPG cluster
#
# Creates a new Postgres user and database in the existing pg-ceph cluster
# (CNPG) for the Bionic Org deployment.
#
# Usage:
#   ./deploy/scripts/setup-postgres.sh [USER] [DATABASE]
#   Defaults: bionicOrg / bionicOrg
#
# Prerequisites:
#   - kubectl access to the cluster
#   - CNPG CLI installed (pg_ctlcluster) or psql
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")/.."  # repo root

PG_USER="${1:-bionicOrg}"
PG_DB="${2:-bionicOrg}"
PG_NS="pg"
PG_CLUSTER="pg-ceph"
PG_PORT="5432"

echo "=== Creating PostgreSQL user & database ==="
echo "  User      : ${PG_USER}"
echo "  Database  : ${PG_USER}"
echo "  Cluster   : ${PG_CLUSTER}.${PG_NS}"
echo ""

# Find the primary pod
PRIMARY_POD=$(kubectl -n "${PG_NS}" get pods -l postgresql="${PG_CLUSTER}" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "${PRIMARY_POD}" ]]; then
  # Try alternative label
  PRIMARY_POD=$(kubectl -n "${PG_NS}" get pods -l role=primary \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
fi

if [[ -z "${PRIMARY_POD}" ]]; then
  echo "ERROR: Could not find CNPG primary pod. Is ${PG_CLUSTER} running?"
  echo "  kubectl -n ${PG_NS} get pods"
  exit 1
fi

echo "  Primary pod: ${PRIMARY_POD}"

# Generate a random password
PG_PASS=$(openssl rand -base64 32)

echo ""
echo "Generated password for ${PG_USER}:"
echo "  ${PG_PASS}"
echo ""
echo "Save this password — it will be stored in Vault."
echo ""

# Connect and create user/database via psql sidecar
echo "Creating user and database..."
kubectl -n "${PG_NS}" exec "${PRIMARY_POD}" -- \
  psql -U postgres -p "${PG_PORT}" -d "${PG_CLUSTER}" <<EOF
-- Create role
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PG_USER}') THEN
    CREATE ROLE ${PG_USER} WITH LOGIN PASSWORD '${PG_PASS}';
    RAISE NOTICE 'Created role ${PG_USER}';
  ELSE
    RAISE NOTICE 'Role ${PG_USER} already exists';
  END IF;
END
\$\$;

-- Create database
SELECT 'CREATE DATABASE ${PG_DB} OWNER ${PG_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PG_DB}')
\gexec

-- Grant schema permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO ${PG_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO ${PG_USER};
GRANT ALL ON SCHEMA public TO ${PG_USER};

-- If database already existed, grant existing objects
DO \$\$
BEGIN
  EXECUTE 'GRANT ALL ON ALL TABLES IN SCHEMA public TO ' || quote_ident('${PG_USER}');
  EXECUTE 'GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO ' || quote_ident('${PG_USER}');
  EXECUTE 'GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO ' || quote_ident('${PG_USER}');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Some grants may have failed (expected if no objects yet)';
END
\$\$;
EOF

# Format the connection string
PG_HOST="${PG_CLUSTER}-rw.${PG_NS}.svc.cluster.local"
DATABASE_URL="postgresql://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}"

echo ""
echo "=== Connection String ==="
echo "  ${DATABASE_URL}"
echo ""
echo "Store this in Vault at t6-apps/bionic-org/config/database_url"
