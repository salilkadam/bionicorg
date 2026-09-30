#!/usr/bin/env bash
# Copyright 2026 SKAD-METHOD contributors
# SPDX-License-Identifier: MIT
#
# Proves every decision branch of skad-heartbeat.sh against a synthetic tree.
# A hook that can refuse to let a session end must be shown to let it end.
#
# Two rules this file learned the hard way, both from review:
#   * EVERY case goes through want()/guard(), which refuses to judge a case whose
#     throwaway workspace was not built. The first version had three cases
#     "passing" against a directory that never existed; the second still had two
#     hand-rolled cases bypassing the guard, and one of THOSE passed vacuously.
#   * A case that asserts a status must use a status from sprint-status.yaml's
#     own header vocabulary. The gap that let `review` disable the whole gate
#     existed because no case had ever used the word.
set -uo pipefail
HOOK_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0; ran=0

mk() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/.claude/hooks" "$d/_skad-output/implementation-artifacts"
  cp "$HOOK_SRC/skad-heartbeat.sh" "$HOOK_SRC/skad-heartbeat-reset.sh" "$d/.claude/hooks/"
  printf '%s\n' "$1" > "$d/_skad-output/implementation-artifacts/sprint-status.yaml"
  shift
  for spec in "$@"; do
    local story rest stem st
    story="${spec%%/*}"; rest="${spec#*/}"; stem="${rest%%:*}"; st="${rest##*:}"
    mkdir -p "$d/_skad-output/implementation-artifacts/tasks/$story"
    printf '# t\n\n**Status:** %s\n' "$st" > "$d/_skad-output/implementation-artifacts/tasks/$story/$stem.md"
  done
  if [ ! -f "$d/_skad-output/implementation-artifacts/sprint-status.yaml" ]; then
    echo "MK-BROKEN: the throwaway workspace was not built" >&2; return 1
  fi
  echo "$d"
}

run_hook() { # $1=dir $2=session-id
  echo "{\"session_id\":\"${2:-s1}\"}" | bash "$1/.claude/hooks/skad-heartbeat.sh" 2>/dev/null
}

guard() { # refuses to judge a case whose workspace is missing
  local label="$1" d="$2"
  if [ -z "$d" ] || [ ! -d "$d" ]; then
    echo "FAIL [$label] the throwaway workspace is missing — this case proved nothing"; rc=1; return 1
  fi
  return 0
}

want() { # label, dir, block|allow, [substring]
  local label="$1" d="$2" expect="$3" needle="${4:-}"
  ran=$((ran+1)); guard "$label" "$d" || return
  local out; out="$(run_hook "$d")"
  local got="allow"; [ -n "$out" ] && got="block"
  if [ "$got" != "$expect" ]; then
    echo "FAIL [$label] got $got, want $expect${out:+ — $out}"; rc=1; rm -rf "$d"; return
  fi
  if [ -n "$needle" ] && ! grep -qF "$needle" <<<"$out"; then
    echo "FAIL [$label] reason does not mention '$needle': $out"; rc=1; rm -rf "$d"; return
  fi
  echo "ok   [$label] $expect"; rm -rf "$d"
}

SP_ACTIVE='sprint:
  1-12-a-story: in-progress
  1-13-another: backlog'
SP_ALLDONE='sprint:
  1-12-a-story: done
  1-13-another: done'
SP_BACKLOG='sprint:
  1-12-a-story: done
  1-13-another: backlog'

# ── the core decisions ──────────────────────────────────────────────────────
want "a task is not passed"            "$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')" block "task-01-x (in-dev)"
want "all tasks passed, story open"    "$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:passed')" block "evidence"

# The task vocabulary is in-dev|in-review|in-test|passed|failed (CLAUDE.md 8a).
# Using only in-dev and passed let a mutation — `!= "passed"` becoming
# `== "in-dev"` — pass the whole suite while making a FAILED task invisible.
# Review constructed exactly that. One case per remaining status.
want "a task that FAILED"              "$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:failed')" block "task-01-x (failed)"
want "a task in-review"                "$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-review')" block "task-01-x (in-review)"
want "a task in-test"                  "$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-test')" block "task-01-x (in-test)"
want "backlog remains"                 "$(mk "$SP_BACKLOG")" block "1-13-another"
want "every story done"                "$(mk "$SP_ALLDONE")" allow

# ── the vocabulary gap that disabled the whole gate (review finding) ────────
want "a story in REVIEW"               "$(mk 'sprint:
  1-12-a-story: review')" block "REVIEW"
want "a story READY-FOR-DEV"           "$(mk 'sprint:
  1-12-a-story: ready-for-dev')" block "ready-for-dev"
want "a story BLOCKED is terminal"     "$(mk 'sprint:
  1-12-a-story: blocked')" allow
want "an UNKNOWN status is outstanding, and says so" "$(mk 'sprint:
  1-12-a-story: marinating')" block "not in the known vocabulary"

# ── stopping on purpose ─────────────────────────────────────────────────────
d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"; touch "$d/.claude/heartbeat.off"
want "kill switch" "$d" allow
d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"; echo q > "$d/.claude/heartbeat.blocked.s1"
want "this session's marker" "$d" allow
d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"; echo 25 > "$d/.claude/.heartbeat-count.s1"
want "budget exhausted" "$d" allow
d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"; echo 24 > "$d/.claude/.heartbeat-count.s1"
want "one continuation left" "$d" block "operator: 0"

# ── fail open, and it must be REAL ──────────────────────────────────────────
d="$(mk "$SP_ACTIVE")"; rm -f "$d/_skad-output/implementation-artifacts/sprint-status.yaml"
want "sprint-status missing" "$d" allow
want "sprint-status unparseable" "$(mk 'not: [valid yaml at all')" allow
d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
mkdir -p "$d/_skad-output/implementation-artifacts/archive"
cp "$d/_skad-output/implementation-artifacts/sprint-status.yaml" "$d/_skad-output/implementation-artifacts/archive/"
want "two sprint-status files" "$d" allow

# THE TRAP review found: an unwritable .claude used to block FOREVER, because
# the budget never persisted so the cap never engaged.
ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "unwritable .claude must NOT trap" "$d"; then
  chmod 555 "$d/.claude"
  out1="$(run_hook "$d")"; out2="$(run_hook "$d")"; out3="$(run_hook "$d")"
  chmod 755 "$d/.claude"
  if [ -z "$out1" ] && [ -z "$out2" ] && [ -z "$out3" ]; then
    echo "ok   [unwritable .claude must NOT trap] allow x3"
  else
    echo "FAIL [unwritable .claude must NOT trap] it blocked — this is the trap-forever path"; rc=1
  fi
  rm -rf "$d"
fi

# python3 absent: cannot decide, so end the turn — and leave a breadcrumb.
ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "python3 absent fails open, observably" "$d"; then
  fake="$d/fakebin"; mkdir -p "$fake"
  for b in bash sh cat find tr rm chmod dirname printf command echo test mapfile; do
    src="$(command -v "$b" 2>/dev/null)"; [ -n "$src" ] && ln -sf "$src" "$fake/$b" 2>/dev/null
  done
  out="$(echo '{"session_id":"s1"}' | env -i PATH="$fake" HOME="$d" bash "$d/.claude/hooks/skad-heartbeat.sh" 2>/dev/null)"
  if [ -z "$out" ] && [ -s "$d/.claude/.heartbeat-degraded" ]; then
    echo "ok   [python3 absent fails open, observably] allow + breadcrumb"
  else
    echo "FAIL [python3 absent] out='${out:0:40}' breadcrumb=$( [ -s "$d/.claude/.heartbeat-degraded" ] && echo yes || echo NO)"; rc=1
  fi
  rm -rf "$d"
fi

# ── a task file with two Status lines must be UNREADABLE, not first-match ──
ran=$((ran+1)); d="$(mk "$SP_ACTIVE")"
if guard "two Status lines is unreadable" "$d"; then
  t="$d/_skad-output/implementation-artifacts/tasks/1-12-a-story"; mkdir -p "$t"
  printf '# t\n\n**Status:** passed\n\nquoting an old note:\n\n**Status:** Draft\n' > "$t/task-01-x.md"
  out="$(run_hook "$d")"
  if grep -qF "UNREADABLE" <<<"$out"; then echo "ok   [two Status lines is unreadable] block + named"
  else echo "FAIL [two Status lines] first-match was taken silently: $out"; rc=1; fi
  rm -rf "$d"
fi

# ── session scoping, both directions (review finding) ───────────────────────
ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "another session's marker does not silence me" "$d"; then
  echo "session A's question" > "$d/.claude/heartbeat.blocked.sessionA"
  out="$(run_hook "$d" sessionB)"
  if [ -n "$out" ]; then echo "ok   [another session's marker does not silence me] block"
  else echo "FAIL [cross-session marker] session B was silenced by session A's marker"; rc=1; fi
  rm -rf "$d"
fi

ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "another session's prompt does not clear my marker" "$d"; then
  echo "session A's question" > "$d/.claude/heartbeat.blocked.sessionA"
  echo '{"session_id":"sessionB"}' | bash "$d/.claude/hooks/skad-heartbeat-reset.sh" >/dev/null 2>&1
  if [ -f "$d/.claude/heartbeat.blocked.sessionA" ]; then
    echo "ok   [another session's prompt does not clear my marker]"
  else echo "FAIL [cross-session reset] session B's prompt deleted session A's question"; rc=1; fi
  rm -rf "$d"
fi

ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "the budget is per session" "$d"; then
  run_hook "$d" sA >/dev/null; run_hook "$d" sA >/dev/null; run_hook "$d" sB >/dev/null
  a="$(cat "$d/.claude/.heartbeat-count.sA" 2>/dev/null)"; b="$(cat "$d/.claude/.heartbeat-count.sB" 2>/dev/null)"
  if [ "$a" = "2" ] && [ "$b" = "1" ]; then echo "ok   [the budget is per session] sA=2 sB=1"
  else echo "FAIL [per-session budget] sA='$a' sB='$b', want 2 and 1"; rc=1; fi
  rm -rf "$d"
fi

# ── the reset hook refills and clears, for THIS session ─────────────────────
ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "reset clears this session's budget and marker" "$d"; then
  run_hook "$d" s1 >/dev/null; echo q > "$d/.claude/heartbeat.blocked.s1"
  echo '{"session_id":"s1"}' | bash "$d/.claude/hooks/skad-heartbeat-reset.sh" >/dev/null 2>&1
  if [ ! -e "$d/.claude/.heartbeat-count.s1" ] && [ ! -e "$d/.claude/heartbeat.blocked.s1" ]; then
    echo "ok   [reset clears this session's budget and marker]"
  else echo "FAIL [reset] count or marker survived"; rc=1; fi
  rm -rf "$d"
fi

# ── waiting on named in-flight work, honoured only while FRESH ─────────────
# Found in use: the agent had launched an adversarial review and could not merge
# until it returned, but "waiting on work I started" is none of the four good
# reasons to stop, so the hook forced busywork.
ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "a FRESH waiting marker is honoured" "$d"; then
  echo "waiting on the adversarial gate for engine PR #45" > "$d/.claude/heartbeat.waiting.s1"
  out="$(run_hook "$d" s1)"
  if [ -z "$out" ]; then echo "ok   [a FRESH waiting marker is honoured] allow"
  else echo "FAIL [fresh waiting marker] it blocked anyway"; rc=1; fi
  rm -rf "$d"
fi

ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "a STALE waiting marker stops counting" "$d"; then
  echo "waiting on something nobody refreshed" > "$d/.claude/heartbeat.waiting.s1"
  # Older than the default 1800s window.
  touch -d "2 hours ago" "$d/.claude/heartbeat.waiting.s1" 2>/dev/null \
    || touch -t "$(date -d '2 hours ago' +%Y%m%d%H%M 2>/dev/null || echo 202001010000)" "$d/.claude/heartbeat.waiting.s1"
  out="$(run_hook "$d" s1)"
  if [ -n "$out" ]; then
    if [ -e "$d/.claude/heartbeat.waiting.s1" ]; then
      echo "FAIL [stale waiting marker] it blocked but left the stale file behind"; rc=1
    else
      echo "ok   [a STALE waiting marker stops counting] block + removed"
    fi
  else echo "FAIL [stale waiting marker] a forgotten wait became a silent stop — the exact property this hook protects"; rc=1; fi
  rm -rf "$d"
fi

ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "another session's waiting marker does not silence me" "$d"; then
  echo "session A waits" > "$d/.claude/heartbeat.waiting.sessionA"
  out="$(run_hook "$d" sessionB)"
  if [ -n "$out" ]; then echo "ok   [another session's waiting marker does not silence me] block"
  else echo "FAIL [cross-session waiting] session B was silenced by session A's wait"; rc=1; fi
  rm -rf "$d"
fi

ran=$((ran+1)); d="$(mk "$SP_ACTIVE" '1-12-a-story/task-01-x:in-dev')"
if guard "the operator speaking clears a wait" "$d"; then
  echo "waiting" > "$d/.claude/heartbeat.waiting.s1"
  echo '{"session_id":"s1"}' | bash "$d/.claude/hooks/skad-heartbeat-reset.sh" >/dev/null 2>&1
  if [ ! -e "$d/.claude/heartbeat.waiting.s1" ]; then
    echo "ok   [the operator speaking clears a wait]"
  else echo "FAIL [reset] the wait survived the operator speaking"; rc=1; fi
  rm -rf "$d"
fi

want_cases=29
[ "$ran" -ne "$want_cases" ] && { echo "FAIL [selftest-itself] $ran cases ran, expected $want_cases"; rc=1; }
[ $rc -eq 0 ] && echo "skad-heartbeat selftest: OK ($ran cases)" || echo "skad-heartbeat selftest: FAILED"
exit $rc
