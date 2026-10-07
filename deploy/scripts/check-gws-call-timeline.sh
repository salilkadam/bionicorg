#!/usr/bin/env bash
# Timeline of gworkspace tool calls: when did they last succeed vs 401?
set -uo pipefail
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "
select to_char(date_trunc('hour', created_at) at time zone 'UTC','MM-DD HH24') hr,
       decision,
       metadata->'execution'->'response'->>'httpStatus' http,
       count(*) n,
       to_char(max(created_at) at time zone 'UTC','HH24:MI:SS') last
from tool_call_events
where tool_name like '%gworkspace%'
group by 1,2,3 order by 1 desc, 4 desc limit 25;" 2>&1 | head -n 32

echo
echo "== last 5 gworkspace calls with outcome detail =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "
select to_char(created_at at time zone 'UTC','MM-DD HH24:MI:SS') t,
       source_kind, decision, outcome, error_message
from tool_call_events
where tool_name like '%gworkspace%' order by created_at desc limit 5;" 2>&1 | head -n 14
