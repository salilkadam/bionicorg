#!/usr/bin/env bash
# Warm the catalog, then dispatch a Drive call in the same breath, and read the
# HTTP ground truth from tool_call_events.
set -uo pipefail
bash deploy/scripts/refresh-connection.sh > /tmp/scratchpad/rw.out 2>&1 && echo "catalog refreshed"
bash deploy/scripts/probe-gws-testcall.sh > /tmp/scratchpad/tw.out 2>&1
echo "== dispatch result =="; tail -n 4 /tmp/scratchpad/tw.out

sleep 3
echo
echo "== ground truth =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "
select to_char(created_at at time zone 'UTC','HH24:MI:SS') t, decision, outcome,
       metadata->'execution'->'response'->>'httpStatus' http
from tool_call_events where tool_name like '%gworkspace%'
  and created_at > now() - interval '3 minutes'
order by created_at desc limit 4;" 2>&1 | head -n 12
