#!/usr/bin/env bash
# List the gworkspace catalog tool names so we can find the delete/trash verb.
set -uo pipefail
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A -c \
  "select tool_name from tool_catalog_entries where connection_id::text like '78ad5e0e%' order by tool_name;" 2>&1 | tr '\n' ' '
