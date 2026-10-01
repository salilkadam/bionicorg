#!/usr/bin/env bash
# Copyright 2026 SKAD-METHOD contributors
# SPDX-License-Identifier: MIT
#
# skad-heartbeat-reset.sh — UserPromptSubmit hook.
#
# The operator speaking means this run is attended again: it refills the budget
# and clears this session's "I need the owner" marker, because the thing that
# marker waited for has arrived.
#
# SCOPED BY SESSION, because review found it was not. Two sessions in one
# checkout shared the marker, so an unrelated conversation's prompt deleted a
# genuine question another session was waiting on. It now clears only the files
# belonging to the session whose prompt this is.
set -uo pipefail
trap 'exit 0' ERR
STATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$STATE" != "/" ] && [ ! -d "$STATE/.claude" ]; do STATE="$(dirname "$STATE")"; done
[ -d "$STATE/.claude" ] || exit 0
STATE="$STATE/.claude"

PAYLOAD="$(cat 2>/dev/null || true)"
SID=default
if command -v python3 >/dev/null 2>&1; then
  SID="$(printf '%s' "$PAYLOAD" | python3 -c '
import json,sys,re
try:
    d = json.load(sys.stdin); s = str(d.get("session_id") or d.get("sessionId") or "default")
except Exception:
    s = "default"
print(re.sub(r"[^A-Za-z0-9_.-]", "", s)[:64] or "default")
' 2>/dev/null || echo default)"
fi

rm -f "$STATE/.heartbeat-count.$SID" "$STATE/heartbeat.blocked.$SID" \
      "$STATE/heartbeat.waiting.$SID" 2>/dev/null || true
# The legacy unscoped marker is this session's only if no scoped one exists —
# clearing it unconditionally is what let one session wipe another's question.
[ -f "$STATE/heartbeat.blocked" ] && [ ! -e "$STATE/heartbeat.blocked.$SID" ] && \
  rm -f "$STATE/heartbeat.blocked" 2>/dev/null || true
exit 0
