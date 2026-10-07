#!/usr/bin/env bash
# Repair the organization grant's credential_secret_refs for Loc-Google Workspace.
#
# tool-gateway.ts resolveCredentialHeadersUnrecorded() reads grant.credentialSecretRefs
# (via connectionGrantCredentialRef), NOT connection.credentialSecretRefs. That list
# was empty, so `if (!grantRef) continue` silently dropped the apikey header and every
# agent-side call went to Kong unauthenticated (anonymous consumer) -> app 401.
#
# Health checks use the connection-level refs, which is why health said "ok" while
# every real call failed.
set -uo pipefail
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg"
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998

# The ref must mirror the connection's ref so connectionGrantCredentialRef() matches
# on configPath.
$PG -c "
update connection_grants g
set credential_secret_refs = jsonb_build_array(jsonb_build_object(
      'secretId', ref->>'secretId',
      'versionSelector', 'latest',
      'configPath', ref->>'configPath',
      'required', true,
      'label', ref->>'label'
    )),
    updated_at = now()
from tool_connections c,
     lateral jsonb_array_elements(c.credential_secret_refs) ref
where c.id::text = '$CONN'
  and g.connection_id = c.id
  and g.kind = 'organization'
  and g.revoked_at is null
  and (g.credential_secret_refs is null or g.credential_secret_refs = '[]'::jsonb)
returning g.id, g.kind, g.status;
" 2>&1 | head -n 8

echo
echo "== grant refs now =="
$PG -c "select jsonb_pretty(credential_secret_refs) from connection_grants where connection_id::text='$CONN';" 2>&1 | head -n 16
