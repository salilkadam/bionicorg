#!/usr/bin/env bash
# Inspect the connection_grants row for the gworkspace connection: does it carry
# the credential secret ref that resolveCredentialHeadersUnrecorded needs?
set -uo pipefail
CONN=78ad5e0e-8c3c-43ab-af13-eff20e870998

echo "== grant columns =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A -c \
  "select column_name from information_schema.columns where table_name='connection_grants' order by ordinal_position;" 2>&1 | tr '\n' ' '
echo; echo

echo "== grants for the connection =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "
select left(g.id::text,8) id, g.kind, g.status, g.credential_source,
       jsonb_pretty(g.credential_secret_refs) refs
from connection_grants g
where g.connection_id::text='$CONN';" 2>&1 | head -n 40
