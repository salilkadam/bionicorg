#!/usr/bin/env bash
# Show the credential_refs (header placement/name) for the gworkspace connection
# and compare with a connection that is known to authenticate fine.
set -uo pipefail
for ID in 78ad5e0e-8c3c-43ab-af13-eff20e870998; do
  echo "== connection $ID =="
  kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A -c "
select jsonb_pretty(to_jsonb(c) - 'config' - 'created_at' - 'updated_at')
from tool_connections c where id::text like '${ID:0:8}%';" 2>&1 | head -n 60
done
echo
echo "== all tool_connections with header placement refs =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "
select left(id::text,8) id, name,
       jsonb_array_elements(credential_refs::jsonb) ref
from tool_connections
where credential_refs is not null and credential_refs::jsonb <> '[]'::jsonb
limit 12;" 2>&1 | head -n 30
