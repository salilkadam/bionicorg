#!/usr/bin/env bash
# Compare the stored Paperclip secret versions against the known-good Kong key
# fingerprint. Only hashes are shown.
set -uo pipefail
SID=23477d30-fe87-4070-bb1a-e9409a778fb9

echo "== stored versions =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "
select version, status, left(value_sha256,16) value_sha, left(fingerprint_sha256,16) fp,
       created_at at time zone 'UTC' created, created_by_type
from company_secret_versions where secret_id::text='$SID' order by version;" 2>&1 | head -n 10

echo
echo "== known-good Kong key (mcp-shared-apikey) fingerprint =="
kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' 2>/dev/null | base64 -d \
  | tr -d '\n' | sha256sum | cut -c1-16 | sed 's/^/  exact-trimmed: /'
kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' 2>/dev/null | base64 -d \
  | sha256sum | cut -c1-16 | sed 's/^/  with-newline : /'
