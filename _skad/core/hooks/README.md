# The SKAD heartbeat

A `Stop` hook that refuses to let a turn end while SKAD work is in flight and
nothing has been recorded as blocked.

## The problem it solves

An agent driving a SKAD sprint ends turns asking *"shall I start the next
story?"* after work the operator has already authorized. The operator has to
notice and say "continue", over and over. **An unattended run does not run.**

That is a judgement failure, and judgement should not be the only thing between
an operator and a finished epic. This hook does not improve the judgement; it
removes the need to trust it.

## Install

Copy `skad-heartbeat.sh` and `skad-heartbeat-reset.sh` to `_skad/core/hooks/`
(or `.claude/hooks/`) and register them:

```json
{
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command",
      "command": "bash \"$CLAUDE_PROJECT_DIR/_skad/core/hooks/skad-heartbeat.sh\"" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command",
      "command": "bash \"$CLAUDE_PROJECT_DIR/_skad/core/hooks/skad-heartbeat-reset.sh\"" }] }]
  }
}
```

Gitignore the runtime state:

```
.claude/.heartbeat-count
.claude/heartbeat.off
.claude/heartbeat.blocked
```

## How it decides

**Local files only** — no network, no `gh`, no tracker call, nothing that can
hang a turn. It finds the project root by walking up to `.claude/`, and finds
`sprint-status.yaml` under `_skad-output/` rather than assuming a path.

**Back to work when** a story is `in-progress` with task files not `passed`; or
`in-progress` with every task passed but not closed out; or nothing is in
progress and the backlog is not empty. The reason it emits **names what is
outstanding**, read fresh, so the agent is told *what to do*.

**Turn ends when** every story is `done`; the budget is spent; `heartbeat.off`
exists; or `heartbeat.blocked` exists.

## Stopping on purpose

Two markers, and they mean different things.

**`.claude/heartbeat.blocked[.<sid>]`** — *"I need the owner."* The only
sanctioned way to stop with work outstanding. The agent writes its question into
the file and ends the turn; the `UserPromptSubmit` hook deletes it when the
operator replies.

Good reasons: an irreversible action needing authorization (a tag, a release, a
deploy), a decision only the owner can make, a failure needing human judgement.
**Not** a good reason: *"shall I continue?"*

**`.claude/heartbeat.waiting[.<sid>]`** — *"I am waiting on named in-flight work
I started."* A review, a build, a remote run. Honoured **only while fresh**
(`SKAD_HEARTBEAT_WAIT_MAX`, default 1800s); a stale one is deleted and the hook
starts blocking again, so a **forgotten wait cannot become a silent stop**.

This one exists because the mechanism hit its own limit in use: the agent had
launched an adversarial review and could not merge until it returned — the
project's rules forbid it — but *"waiting on work I started"* is none of the
four good reasons, so the hook forced busywork. That is a worse version of what
it was built for.

Both keep the same property: **"why did it stop" is answerable from a file**
rather than from memory, and a stop with no marker and outstanding work is a
visible bug.

`.claude/heartbeat.off` is the kill switch — present means never continue.

## Bounds, and failing open

A budget — `SKAD_HEARTBEAT_MAX`, default **25** — is spent one per continuation
and **refilled when the operator speaks**, so a runaway costs at most one
exchange. `heartbeat.off` is the kill switch.

Any internal error, unreadable state, missing file, or **two `sprint-status.yaml`
files it cannot choose between** lets the turn end. A hook that wedges a session
is far worse than one that occasionally lets it stop early.

Set `SKAD_SPRINT_STATUS` to name the file explicitly if a project legitimately
has more than one.

## What it cannot do

It works **inside a running session**. It cannot restart one that has exited or
crashed; that needs a scheduled wake-up, which is a different mechanism.

## Proving it

```
bash .claude/hooks/skad-heartbeat_test.sh
```

**29 cases** over every branch. The ones that exist because adversarial review
found the gap, not because someone imagined it:

| Case | The defect it exists for |
|---|---|
| a story in `review`, `ready-for-dev`, or an **unknown** status | the first version listed the statuses meaning "working" and treated every other as nothing-to-do — so it **let the turn end through the whole PR-open phase of every story**, the exact problem it exists to prevent |
| an **unwritable `.claude`** must not trap | the budget was written with `|| true`; on a read-only mount it never persisted, the cap never engaged, and the hook **blocked forever** — the opposite of the fail-open it documented |
| **python3 absent** fails open *and leaves a breadcrumb* | otherwise the degradation is invisible from outside the process |
| a task file with **two `Status:` lines** | the parse took the first match, and a body that quotes a status-shaped line is not hypothetical — one exists in this repo |
| **another session's marker / prompt** | two sessions shared one `.claude/`: one session's prompt deleted another's genuine question, and one session's marker silenced another's Stop event |
| a task that **failed**, **in-review**, **in-test** | the suite used only `in-dev` and `passed`, so a mutation making every other status invisible passed all of it — review constructed exactly that |

Every case goes through a guard that **refuses to judge a case whose throwaway
workspace was not built**. The first version had three cases passing against a
directory that never existed; the second still had two hand-rolled cases
bypassing the guard, and one of those passed vacuously. That is the defect class
this suite keeps finding in itself.
