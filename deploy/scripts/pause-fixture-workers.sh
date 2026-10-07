#!/usr/bin/env bash
# Silence eval-fixture agent noise.
#
# The "* Worker Co" companies are evaluation fixtures whose codex_local agents
# have no credentials, so they fail roughly every 90 s and bury the real signal
# in the run log.
#
# The board API is company-scoped (getAccessibleResource), so these foreign-company
# agents 404 on /agents/:id/pause — patch them in SQL instead.
#
# Usage:
#   bash deploy/scripts/pause-fixture-workers.sh           # pause (dry-run first)
#   CONFIRM=1 bash deploy/scripts/pause-fixture-workers.sh # apply
set -uo pipefail
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg"
PATTERN=${1:-'Worker Co'}
REASON="paused by ops: eval fixture company, no credentials (see deploy/scripts/pause-fixture-workers.sh)"

echo "== matching agents =="
$PG -c "
select a.status, count(*)
from agents a join companies c on c.id = a.company_id
where c.name ~ '$PATTERN'
group by 1;" 2>&1 | head -n 6

if [ "${CONFIRM:-0}" != "1" ]; then
  echo
  echo "dry run only — re-run with CONFIRM=1 to pause these agents"
  exit 0
fi

echo
echo "== pausing =="
$PG -c "
update agents a
set status = 'paused',
    paused_at = coalesce(a.paused_at, now()),
    metadata = coalesce(a.metadata,'{}'::jsonb) || jsonb_build_object('pauseReason', '$REASON'),
    updated_at = now()
from companies c
where c.id = a.company_id
  and c.name ~ '$PATTERN'
  and a.status <> 'paused'
returning substring(a.id::text for 8) as agent;" 2>&1 | tail -n 6

echo
echo "== verify =="
$PG -c "
select a.status, count(*)
from agents a join companies c on c.id = a.company_id
where c.name ~ '$PATTERN'
group by 1;" 2>&1 | head -n 5

echo
echo "To undo: clear status='paused'/paused_at for the same company-name match."
