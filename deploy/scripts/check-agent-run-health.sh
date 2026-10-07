#!/usr/bin/env bash
# Post-fix health sweep with correct column names.
set -uo pipefail
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg"

echo "== Reliora agents by status =="
$PG -c "select status, count(*) from agents where company_id::text like '62d63984%' group by 1 order by 2 desc;" 2>&1 | head -n 8

echo
echo "== run outcomes, last 2 h (Reliora) =="
$PG -c "
select r.status, count(*),
       to_char(max(r.created_at) at time zone 'UTC','HH24:MI') last
from heartbeat_runs r join agents a on a.id = r.agent_id
where r.created_at > now() - interval '2 hours'
  and a.company_id::text like '62d63984%'
group by 1 order by 2 desc;" 2>&1 | head -n 10

echo
echo "== fixture-worker noise (any new runs since pause?) =="
$PG -c "
select a.status agent_status, count(r.id) runs_last_2h
from heartbeat_runs r
join agents a on a.id = r.agent_id
join companies c on c.id = a.company_id
where c.name ~ 'Worker Co' and r.created_at > now() - interval '2 hours'
group by 1;" 2>&1 | head -n 6

echo
echo "== newest error-level lines (any source, last 30 min) =="
$PG -c "
select to_char(e.created_at at time zone 'UTC','HH24:MI') t, left(a.name,22) agent, left(e.message,80) msg
from heartbeat_run_events e join agents a on a.id = e.agent_id
where e.level in ('error','warn') and e.created_at > now() - interval '30 minutes'
order by e.created_at desc limit 8;" 2>&1 | head -n 14
