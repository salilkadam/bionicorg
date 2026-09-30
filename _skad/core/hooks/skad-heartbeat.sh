#!/usr/bin/env bash
# Copyright 2026 SKAD-METHOD contributors
# SPDX-License-Identifier: MIT
#
# skad-heartbeat.sh — a Stop hook that refuses to let a turn end while SKAD work
# is in flight and there is no good reason to stop.
#
# WHY THIS EXISTS. The agent kept ending turns with questions it did not need to
# ask — "shall I start the next story?" — when the standing instruction was to
# continue. That is a judgement failure, and judgement should not be the only
# thing between an operator and a finished epic. This does not improve the
# judgement; it removes the need to trust it.
#
# CONTRACT. Claude Code runs this when the main agent finishes, with the hook
# payload on stdin. Printing {"decision":"block","reason":"..."} sends the agent
# back to work; printing nothing lets the turn end.
#
# WHAT ADVERSARIAL REVIEW CHANGED, because each was a real defect:
#
#   * OUTSTANDING IS THE DEFAULT. The first version listed the statuses that
#     mean "working" (in-progress, backlog) and treated everything else as
#     nothing-to-do. sprint-status.yaml's own header defines FIVE story
#     statuses, so `review` and `ready-for-dev` were invisible — the hook let
#     the turn end through the whole PR-open phase of every story, which is
#     precisely the problem it exists to prevent, reintroduced by its own
#     vocabulary gap. It now lists the TERMINAL statuses instead, and anything
#     else — including a status nobody has thought of — counts as outstanding.
#
#   * FAILING OPEN IS VERIFIED, NOT ASSUMED. The budget was written with
#     `echo … || true`. On a read-only or full .claude the write silently did
#     nothing, the count never incremented, and the 25-turn cap NEVER ENGAGED —
#     the hook blocked forever, which is the exact opposite of the fail-open it
#     documented, in the scariest direction. The write is now checked by
#     reading it back, and a budget that cannot be persisted ends the turn.
#
#   * THE BUDGET AND THE MARKER ARE PER SESSION. Two sessions in one checkout
#     shared both: one session's prompt deleted another's genuine "I need the
#     owner" marker, and one session's marker silenced another's Stop event.
#     Both are now keyed by the session id the payload carries.
#
# IT FAILS OPEN — and that is now true rather than merely claimed. Any error,
# unreadable state, missing file, absent python3 or unwritable budget ends the
# turn, which is the behaviour without the hook. A hook that wedges a session is
# far worse than one that occasionally lets it stop early. When it degrades it
# leaves .claude/.heartbeat-degraded saying why, because a mechanism that can
# fail silently is one nobody can debug.
#
#   .claude/heartbeat.off             — kill switch, all sessions.
#   .claude/heartbeat.blocked[.<sid>] — the agent's question for the owner. The
#                                       only sanctioned way to stop mid-flight.
#   .claude/heartbeat.waiting[.<sid>] — the agent is waiting on NAMED in-flight
#                                       work it started (a review, a build, a
#                                       remote run). Honoured only while FRESH;
#                                       see below.
#   .claude/.heartbeat-count.<sid>    — this session's spent budget.
#
# WHY `waiting` EXISTS, and why it expires. Found in use: the agent had launched
# an adversarial review and could not merge until it returned — rule 8 forbids
# it — but "waiting on work I started" is none of the four good reasons to stop,
# so the hook forced busywork. That is a worse version of what it was built for.
#
# It is honoured only while the file is FRESHER than SKAD_HEARTBEAT_WAIT_MAX
# (default 1800s). A wait that goes stale starts blocking again, so a forgotten
# one cannot become a silent stop — which is the whole property this hook
# protects. The file says WHAT is being waited on, so "why did it stop" stays
# answerable from disk.
set -uo pipefail
trap 'exit 0' ERR

allow() { exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -d "$ROOT/.claude" ]; do ROOT="$(dirname "$ROOT")"; done
[ -d "$ROOT/.claude" ] || allow
STATE="$ROOT/.claude"
MAX_CONTINUES="${SKAD_HEARTBEAT_MAX:-25}"

PAYLOAD="$(cat 2>/dev/null || true)"

# python3 does the parsing. Without it this hook cannot decide anything, so it
# ends the turn — and says so on disk, because an unobservable degradation is
# the failure mode this whole project keeps finding.
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is not on PATH; the heartbeat cannot read sprint-status and let the turn end" \
    > "$STATE/.heartbeat-degraded" 2>/dev/null || true
  allow
fi

# The session id scopes the budget and the marker. Absent → "default", which is
# no worse than the old shared behaviour and no better; it is not fabricated.
SID="$(printf '%s' "$PAYLOAD" | python3 -c '
import json,sys,re
try:
    d = json.load(sys.stdin)
    s = str(d.get("session_id") or d.get("sessionId") or "default")
except Exception:
    s = "default"
print(re.sub(r"[^A-Za-z0-9_.-]", "", s)[:64] or "default")
' 2>/dev/null || echo default)"

COUNT_FILE="$STATE/.heartbeat-count.$SID"
BLOCKED="$STATE/heartbeat.blocked.$SID"

# ── reasons to stop that are not "nothing left to do" ────────────────────────
[ -f "$STATE/heartbeat.off" ] && allow
[ -f "$BLOCKED" ] && allow
[ -f "$STATE/heartbeat.blocked" ] && allow   # unscoped marker: honoured, legacy

# Waiting on named in-flight work, honoured only while fresh.
WAITING="$STATE/heartbeat.waiting.$SID"
[ -f "$WAITING" ] || WAITING="$STATE/heartbeat.waiting"
if [ -f "$WAITING" ]; then
  wait_max="${SKAD_HEARTBEAT_WAIT_MAX:-1800}"
  now="$(date +%s 2>/dev/null || echo 0)"
  mtime="$(stat -c %Y "$WAITING" 2>/dev/null || echo 0)"
  age=$(( now - mtime ))
  if [ "$now" -gt 0 ] && [ "$mtime" -gt 0 ] && [ "$age" -lt "$wait_max" ]; then
    allow
  fi
  # Stale, or the age could not be read. Either way it stops counting as a
  # reason — a wait nobody refreshed is indistinguishable from a forgotten one,
  # and the safe reading of "cannot tell" here is to keep working.
  rm -f "$WAITING" 2>/dev/null || true
fi

count=0
[ -f "$COUNT_FILE" ] && count="$(tr -cd '0-9' < "$COUNT_FILE" 2>/dev/null || echo 0)"
[ -z "$count" ] && count=0
[ "$count" -ge "$MAX_CONTINUES" ] && allow

# ── is there work in flight? ────────────────────────────────────────────────
SPRINT="${SKAD_SPRINT_STATUS:-}"
if [ -z "$SPRINT" ]; then
  mapfile -t _found < <(find "$ROOT/_skad-output" -maxdepth 3 -name sprint-status.yaml 2>/dev/null)
  [ "${#_found[@]}" -eq 1 ] || allow
  SPRINT="${_found[0]}"
fi
[ -f "$SPRINT" ] || allow

outstanding="$(python3 - "$SPRINT" "$ROOT" <<'PY' 2>/dev/null || true
import sys, pathlib, re

sprint = pathlib.Path(sys.argv[1]); root = pathlib.Path(sys.argv[2])
rows = re.findall(r"^\s{2}([0-9][\w.-]+):\s*(\S+)", sprint.read_text(), re.M)
if not rows:
    sys.exit(1)                       # could not read it: fail open

# TERMINAL statuses — the only ones that mean "nothing more to do here".
# Everything else is outstanding, INCLUDING a status this list has never heard
# of, because the alternative is the gate silently switching itself off when
# someone adds a word to the vocabulary. `blocked` is terminal for the agent:
# it is a recorded need for someone else.
TERMINAL = {"done", "optional", "skipped", "blocked", "cancelled", "n/a"}

lines, unknown = [], []
for key, state in rows:
    st = state.split("#", 1)[0].strip().lower()
    if st in TERMINAL:
        continue
    if st not in {"backlog", "ready-for-dev", "in-progress", "review"}:
        unknown.append(f"{key}: {state}")

    d = root / "_skad-output/implementation-artifacts/tasks" / key
    if st == "in-progress" and d.is_dir():
        todo, unreadable = [], []
        for f in sorted(d.glob("*.md")):
            ms = re.findall(r"^\*\*Status:\*\*\s*(\S+)", f.read_text(), re.M)
            if len(ms) != 1:
                # Not exactly one Status line: a body can quote a status-shaped
                # line, and taking the first match would read the wrong one.
                unreadable.append(f"{f.stem} ({len(ms)} Status lines)")
            elif ms[0] != "passed":
                todo.append(f"{f.stem} ({ms[0]})")
        if todo or unreadable:
            parts = todo + [u + " — UNREADABLE" for u in unreadable]
            lines.append(f"story {key} is in-progress with {len(parts)} task(s) not passed: "
                         + ", ".join(parts[:4]) + (" …" if len(parts) > 4 else ""))
        else:
            lines.append(f"story {key} is in-progress and every task file reads passed — "
                         f"it needs its evidence, its tracker row and its merge, or its status changed")
    elif st == "in-progress":
        lines.append(f"story {key} is in-progress and has no task directory yet — it needs its task files")
    elif st == "review":
        lines.append(f"story {key} is in REVIEW — a PR is open and unmerged, or its review is unactioned")
    elif st == "ready-for-dev":
        lines.append(f"story {key} is ready-for-dev and not started")

if not lines:
    backlog = [k for k, v in rows if v.split("#", 1)[0].strip().lower() == "backlog"]
    if backlog:
        lines.append(f"no story is in-progress and {len(backlog)} remain in backlog; the next is {backlog[0]}")

for u in unknown:
    lines.append(f"status not in the known vocabulary, treated as outstanding — {u}")

print("\n".join(lines))
PY
)"

[ -z "$outstanding" ] && allow

# ── spend a continuation, and PROVE the spend persisted ─────────────────────
want=$((count + 1))
echo "$want" > "$COUNT_FILE" 2>/dev/null || true
got="$(tr -cd '0-9' < "$COUNT_FILE" 2>/dev/null || true)"
if [ "$got" != "$want" ]; then
  # The budget cannot be persisted, so the cap can never engage and blocking
  # here would block forever. Found by review: this exact path used to trap a
  # session on a read-only .claude.
  echo "cannot persist the heartbeat budget at $COUNT_FILE; the cap could never engage, so the turn was allowed to end" \
    > "$STATE/.heartbeat-degraded" 2>/dev/null || true
  allow
fi
rm -f "$STATE/.heartbeat-degraded" 2>/dev/null || true

python3 - "$outstanding" "$((MAX_CONTINUES - want))" <<'PY' 2>/dev/null || exit 0
import json, sys
print(json.dumps({"decision": "block", "reason": f"""Do not stop yet — SKAD work is still in flight and nothing has been recorded as blocked.

Outstanding, read from sprint-status.yaml and the task files just now:
{sys.argv[1]}

Continue the work. Specifically: do NOT end a turn to ask whether to proceed to
the next task, the next story or the next epic — the standing instruction is to
continue, and merging after local gates pass is pre-authorized.

If you genuinely need the owner — an irreversible action (a tag, a release, a
deploy), a decision only they can make, or a failure needing human judgement —
then write the question to .claude/heartbeat.blocked and stop. That file is the
ONLY way to stop while work is outstanding, and it makes "why did it stop"
answerable from disk instead of from memory.

Continuations left before this hands back to the operator: {sys.argv[2]}."""}))
PY
