---
name: dev-tasks
description: 'Orchestrate task-by-task story implementation with automated implement → review → test pipeline. Use when the user says "dev tasks", "run dev tasks", or "implement tasks for [story]"'
---

# Dev Tasks Workflow

**Goal:** Orchestrate atomic task-level implementation across tasks, stories, and epics using a 3-phase pipeline per task: Implement → Review → Test. Advance automatically through tasks and stories; halt at configurable checkpoints for human sign-off.

**Which path is this?** There are two ways to implement a story. This is the ORCHESTRATED
one: separate sub-agents per phase, with the process rules, tracker mirroring, dependency
gating and the story acceptance gate. It reads its state from task files and HALTs without
them. `dev-story` is the single-agent path — it also reads task files when present, so the
choice between them is not about which files exist but about whether the story should be
gated. What `dev-story` gives up is listed in its own header.

**Your Role:** Orchestrator. You do not write production code directly. You spawn and monitor sub-agents, read state from task files and sprint-status, and advance the pipeline.

- Communicate all responses in {communication_language} tailored to {user_skill_level}
- Execute ALL steps in exact order; do NOT skip steps
- NEVER advance to the next task until the current task has `passed` status — the only exception is a parallel pipeline started under step 3's R9 conditions, for a task that does not depend on the current one
- NEVER modify test assertions to make a test pass — only production code is fixed
- Read state from files at the start of every iteration — never assume state from memory

## MANDATORY PROCESS RULES (override defaults)

- **R0 — The tracker moves with the work, or the work is not done.** Every phase
  transition below is mirrored into OpenProject **in the same step that changes the task
  file**, with one command:

  ```bash
  python3 _skad/bmm/lib/op-status.py task  <story-key> <task-file-stem> in-dev|in-review|in-test|passed|failed --note "…"
  python3 _skad/bmm/lib/op-status.py story <story-key> in-progress|review|done|blocked   --note "…"
  python3 _skad/bmm/lib/op-status.py bug   <story-key> "<subject>" --body-file <path>
  python3 _skad/bmm/lib/op-status.py check [story-key]      # 0 agreed, 1 drift/unverified, 2 nothing compared
  ```

  A status update is not a courtesy to a dashboard: a story finished in the repo and
  stale in the tracker is a story two people will disagree about, and the disagreement
  surfaces at the worst moment. **`check` is what makes this real** — it compares the
  tracker against `sprint-status.yaml` and every task file's own `**Status:**` line and
  fails on any disagreement, in either direction. Run it at every story boundary (step
  7) and whenever you are unsure. It has been shown failing on both a stale story row
  and a stale task row; a sync nobody can fail is a sync nobody should trust.

  **A write and a check fail differently, on purpose.** Every `task`/`story`/`bug`
  write logs and continues when OpenProject is unreachable — the work is real whether
  or not the tracker heard about it, and halting the pipeline over a tracker outage
  would make the rule its own worst failure mode. `check` is the opposite: a story
  does not close while it reports a disagreement, **or an item it could not verify**.
  An unread work package is never counted as agreement.

  **What `check` does not cover, so nobody mistakes silence for a clean tracker.** A
  story in `backlog` or `ready-for-dev`, or a task in `ready-for-task`, implies nothing
  about the tracker and is compared against nothing; the summary line counts those
  separately, and a run that compared nothing says so. `check` compares one thing per
  item — the status id — not type, parent, project or duplicates.

  **Where the tracker moves outside this file.** This pipeline writes story `done` itself,
  at the story acceptance gate in step 7, and only there — after the story's criteria have
  passed against a deployed or running system. `review` is an intermediate state meaning a
  pull request is open. At a story boundary `code-review` is told to write no story status at
  all; its step 5 writes `done` only when a human runs it directly by the `CR` command,
  outside this pipeline, carrying the same `op-sync` action and the same boundary `check`. Story `blocked` is written at five sites and nowhere else: one in step 3 — a hard dependency whose gate has not passed (R19) — and four in step 7. One of the five HALTs the run, the infra gap in Phase 4; the other four block only that story's lane and carry on: a code review that comes back Blocked, two consecutive review rounds that only restate, a verdict line still unreadable after one ask, and the R19 case. The epic acceptance gate also HALTs, but it writes no story status at all — it files a Bug under the EPIC, so it is not one of these five.
  Both are in scope of R0; neither is in this workflow's per-task phase loop.

- **R1 — No integration test with mocks.** Integration/E2E tests MUST hit the project's REAL infrastructure (its actual databases, auth, message/streaming, object store, external/AI services). The Test phase REJECTS any integration test that uses in-memory fakes, an in-process server with stubbed downstreams, monkeypatched services, or fake databases — that is a defect, not a pass. (Unit tests may mock; integration tests may not.)
- **R2 — Infra gap → Infrastructure Epic.** If a real-infra test cannot run because infrastructure isn't wired, do NOT mock and do NOT mark the task/story `passed` — HALT, record the gap against an **Infrastructure Epic**, and leave the story blocked.
- **R3 — Traceability.** Every task links to its story, story to epic, epic to capability, capability to the product GOAL. Flag any orphan or unwired connection in the run output.
- **R4/R5 — QA adversarial real-app gate.** A story/epic is NOT complete until the **Phase 4 QA adversarial verification** (below) passes: the adversarial QA role drives the REAL application (browser / agent-browser / Playwright) on real infrastructure, audits the story's integration tests for mocks, and tries to break the user journey. Spawn the QA agent (`bmm/agents/qa`). An EPIC gets its own run of that gate at its last story — the epic acceptance gate in step 7 — because a set of individually correct stories can still leave the epic's criteria unmet, and no story-level gate can see that.
- **R6 — Self-initiated QA, before commit/merge/done.** Trigger the Phase 4 QA pass YOURSELF (never wait to be asked) whenever a task/story adds or changes tests/verification and before opening a PR or marking done. QA must FETCH/drive the real artifact (not trust a 200 / truthy field) — a check that does not exercise the artifact is a false-green defect, fixed in the same cycle.
- **R7 — Sub-agent prompts carry their environment.** A sub-agent starts with zero context and cannot use what its prompt does not tell it. Every implement, review, test, fix, code-review and QA prompt opens with the `{{execution_context}}` block (see *Sub-Agent Execution Context* below): the exact repo path and branch, how to load credentials without printing them, the toolchain PATH, where the task file lives, and that the orchestrator — not the sub-agent — commits orchestration files (task files, sprint status, tracker maps, review reports). *Why:* a reviewer once reported a service token "invalid" only because nobody had told it how to load the token.
- **R8 — Never park an agent waiting on a background job.** A sub-agent that starts a background command and ends its turn to "wait" is never woken; it stalls silently while looking busy. It also happens without anyone asking for a background job: agent runtimes cap a single tool call (Claude Code's Bash tool at 600 seconds), and a call that requests a longer timeout is quietly moved to the background, parking the agent on a notification it will never act on. *Why:* a dispatch prompt once told a test agent to wait with a 1,900,000 ms timeout, and the agent parked. So every dispatch prompt requires — and the orchestrator itself follows — three things. **(a)** Keep every wait loop and every gate call under about 9 minutes, and repeat the call until the work is done; a longer wait, such as a stall interval, is taken in slices. **(b)** Run a gate that can take longer detached, `nohup sh -c '( <gate> ) > <log> 2>&1; echo EXIT=$? >> <log>' >/dev/null 2>&1 & echo $! > <log>.pid`, with `<log>` an absolute path unique to that gate, and keep the turn: poll `<log>` for its `EXIT=` line in foreground slices of under 9 minutes each, for at most a stated number of slices (the gate's expected duration plus a margin — a poll with no maximum is not bounded). If the maximum is reached, or the wrapper is gone (`kill -0 "$(cat <log>.pid)"` fails), re-read `<log>` once more at that moment — the gate may have finished since the last check — and only if it still has no `EXIT=` line did the gate fail unrecorded: report a failure, never "still running". The subshell matters — an `exit` inside the gate must not skip the `EXIT=` line. **(c)** When a sub-agent stops before reaching a terminal status — parked, waiting, or asking a question — the orchestrator **resumes that same agent with a message**; it never spawns a duplicate to redo the work beside the first. Each resume counts as one attempt toward the retry limit of the phase it stopped in, the same limit a stall respawn counts toward — {{retry_count}} in Phase 1 (step 4), {{review_retry_count}} in Phase 2 (step 5) or {{test_retry_count}} in Phase 3 (step 6), at most 2 retries each — and once that limit is exceeded the task follows that phase's failure path. An agent that keeps stopping early is never resumed without end.
- **R9 — Parallel agents: yes. Idle or duplicate agents: no.** Run genuinely independent work in parallel: tasks with no dependency between them (R11), no shared files, and separate repos or worktrees. Serialize only what must be serialized: dependent tasks, edits to the same file, and memory-heavy full gates (R12). After recording any agent's result, list what is still running — sub-agents **and** background shell jobs — and stop anything no longer needed. When reporting agent counts, report running agents separately from finished history entries. Before any HALT, stop every other running pipeline's sub-agents and background jobs, or record which are still running and where their logs are — a HALT ends the run, and nothing else will supervise them.
- **R10 — The verification run contract.** A task file's Verification Commands are run **each individually**, one line per invocation, and a non-zero exit is a failure. A line starting with `!` succeeds exactly when its negated command fails. Every review, proof and planted-defect test exercises the checks in that same mode — never as one `set -e` script: bash exempts `!` pipelines from errexit, so a whole-block run manufactures false "this gate cannot fail" findings. Security-critical checks such as leak scans must still fail closed in **both** modes: pass only on `grep` exit 1 (file read, no match) and treat exit 2 (unreadable or missing) as a failure; never print a matching secret line (`grep -l`, not `grep -n`); and fail when a credential the check needs reads empty.
- **R11 — Parse `Requires:` as written, not by pattern.** Dependency lines use ranges and prose — "Tasks 1, 2a and 2b", "2a–2g", "Tasks 1–7", "all implementation tasks". Expand every range, including lettered splits, and read the prose before deciding a task is ready or may run in parallel. Matching single task IDs out of the line marks dependent tasks as ready. A line that cannot be expanded unambiguously means the task depends on every task before it.
- **R12 — Resource-aware gates.** On a memory-limited host, full race-test, e2e and other memory-heavy gates run one at a time, never beside each other. Before calling a `signal: killed` (exit 137) a test failure, check the memory peak (e.g. the cgroup's `memory.peak`) — an OOM kill looks exactly like a failing test. Sub-agents run package-level checks for what their task touched; the orchestrator runs the full gate, serially, at the story boundary.
- **R13 — Do not hijack shared checkouts.** Before pointing a sub-agent at a repo, check its current branch and `git status`. If the main checkout is on another session's branch or holds uncommitted work, create a `git worktree` for the task and point the sub-agent at it explicitly. A task file's hard-coded repo path is then substituted with the worktree path, and the prompt says so in so many words. Never switch branches in, or stash from, a checkout another session is using.
- **R14 — Merging is conditional.** Merging is not part of this pipeline by default. Only when the project owner has given standing authorization to merge after testing does the orchestrator merge — and then as described in *Merging Stacked PRs* below.
- **R15 — A load-bearing gate with several conditions ships with a table-driven test of every branch, in the same commit as the gate.** Load-bearing means its combined outcome decides something: a status transition, an authorization, whether a change is applied, whether money moves, whether a safety limit holds. An ordinary two-operand `if` in application code is not that, and does not owe a table. A condition nobody enumerated is discovered one run at a time, and each discovery costs a whole run. "Every branch" is: each condition failing on its own, all conditions passing, and every combination the code treats differently — precedence, short-circuit order, and any pair whose joint outcome is not implied by either alone. One row per condition is the floor, not the bar. Each row names the outcome AND the reason the caller is given, and the test is registered as one of the task's Verification Commands so the pipeline runs it and the planted-defect check in Phase 2 can prove it fails. *Why:* a five-condition eligibility gate (a verdict, a required field, a similarity floor, a kind match, a subject relation) was diagnosed one condition per 20-minute run, six runs, when one table test would have enumerated all five before the first.
- **R16 — Iterate against a warm environment; pay for a cold one only at a boundary.** When a hypothesis needs an environment that already exists, run the one test against the standing environment. Full provisioning — cluster, builds, image loads, install — belongs at the evidence, acceptance and merge boundaries, not in a diagnosis loop, and those boundaries always reprovision from scratch rather than reusing what a diagnosis left behind. A warm environment goes stale: record the commit and the image or chart version it was provisioned from, and treat any result from it as void once the code under test has moved past that — a warm environment that silently no longer matches HEAD turns saved setup time into a wrong answer, which costs more than the runs it saved. How this one is checked, since it leaves no trace in a diff: every result you report carries the environment line, in the task file's Task Agent Record as well as in your report. A result reported without it is not evidence. Unlike R15 and R17, which the story-boundary code review checks independently, nothing downstream can see this one in a diff — so it rests on the report itself, and an orchestrator reading a result with no environment line asks for it before recording the result as evidence. Measure the split before assuming it is cheap: in one story 63–74% of every 20–24 minute run was setup, and every diagnostic rerun paid it again to re-ask a single question. The environment a diagnosis reuses is named in the report, so the evidence run that follows is not confused with it.
- **R17 — Every budget is computed and checked, never hand-summed.** This covers any bound whose violation is a failure someone has to diagnose — timeouts, deadlines, retry and backoff totals, size, token and payload limits, anything derived from a set of parts (stage timeouts inside an outer bound, a client timeout inside a caller's deadline). It does not cover a figure that is only displayed. Such a bound gets a check that recomputes the sum from the parts and fails when they outgrow it — never an assertion against a hand-written total, which drifts with the thing it is meant to catch — and that check is registered as a Verification Command and proved by planting a part that breaks it. *Why:* a hand-summed harness bound drifted twice as stages accrued, and both times a person found it by re-reading the arithmetic.
- **R18 — HALT is for the run; `blocked` is for the lane.** A HALT ends the RUN: R9 requires stopping every other pipeline's sub-agents and background jobs first, so one story's problem stops all the parallel work this harness exists to do. Use it only when continuing would write more state on top of state nobody can describe — a commit, push or PR that failed, a tracker and repo that disagree — or when the operator asked (`autonomy_mode`), or when the failure is in the TOOLING and will recur on whatever you pick up next (say so, and say what evidence makes it the tooling rather than this item). Everything about one item's CONTENT — a review that refuses this story, rounds converging on restatements — blocks that item's lane instead: mark it `blocked` with the reason, file it, stop only its sub-agents, and continue with work that does not depend on it. Discovery skips a `blocked` story by construction — it looks only for `in-progress`, `ready-for-dev` and `backlog` — but ONLY once `blocked` is written to `development_status` in sprint-status.yaml, which is the file it reads. `op-status.py story … blocked` writes the TRACKER, not that file; a lane block that mirrors the tracker and forgets the local status leaves the story `in-progress`, and step 1 resumes it ahead of everything else. Both writes, every time, and the LOCAL one first — a story locally `blocked` whose tracker was not reached is caught by `op-status.py check` as drift, while a tracker-only block is invisible to it and silently resumes. **The epic acceptance gate is the deliberate exception and stays a HALT**: its content failure is not contained to one item, because the next epic is usually built on the one that failed, and nothing yet records which epics depend on which (R19's `Depends on:` will make that decidable — until every epic declares it, halting is the honest default). Frequency argues the same way: that gate fires at most once per epic, a per-story gate once per story. **The trade lane-blocking makes is immediacy for throughput**, and it is only safe while the blocked count is visible: report it every time a lane blocks, and treat a rising count as the thing a HALT would have told you at once.
- **R19 — Never start work whose hard dependency is unmet.** Every epic, feature, story and task carries its dependencies in one of two spellings, and you read BOTH: **`Depends on:`** is canonical and carries `hard:`/`soft:` per line; **`Blocked on:`** is its older spelling, still the one most existing artifacts use, and every entry in it is HARD by definition — that is what the word means. Treat them as the same field. **If NEITHER appears, the artifact is incomplete: say so and stop.** Do not read a missing field as `none` — that is the check passing because it looked at nothing, which is worse than failing, and it is the exact shape of defect the rest of these rules exist to catch. Before picking up an item, check that each hard dependency is satisfied — its acceptance gate passed, not merely that it exists — and skip it if not, rather than building on a foundation nobody verified. An item blocked on an unmet dependency is `blocked` with that dependency named, which is a lane block under R18, not a HALT.
- **R20 — A test is changed only because the TEST was wrong.** Tests exist to hold the acceptance criteria, so a test may be changed for exactly two reasons: it was written incorrectly, or it did not match the criterion it claims to verify. **"It was failing" is not one of them.** A failing test is evidence about the CODE until someone argues otherwise — it takes an argument, not an edit. Every test change records which of the two reasons applies, and a change that touches a test and the code that test exercises *together* is the signature of weakening a test to go green: not forbidden, because sometimes both really are wrong, but never waved through, and the burden is on whoever changed the test. A test that verifies no stated criterion is unanchored — nothing says what it is for, so nothing can say whether changing it was legitimate.
- **R21 — Decide autonomously only what a written criterion decides.** An autonomous decision must be able to NAME the acceptance criterion or goal it serves; a decision that cannot name one is not a judgment call, it is an escalation. This is the bar, and it is checkable afterwards from what you recorded. Two consequences: a gate belongs where the SPEC IS SILENT or contradicts itself, not where the work merely feels consequential — a stop placed over something a written criterion already covers is a stop that should not exist, and an ambiguity with no criterion is one that should, however small the work looks. And the criterion has to be readable by the agent at the moment it decides: an autonomy bar resting on a criterion the deciding agent cannot see grants autonomy by default, which is the opposite of what it says.
- **R22 — A Verification Command that cannot fail is not a gate.** Every registered line must be able to fail, and these shapes cannot. **A line ending in a pager reports the PAGER's status** — `cmd 2>&1 | tail -20` exits 0 over a failure; capture the status and re-raise it, or redirect to a log and `exit $ec`. **A count that is produced and never compared passes on any non-zero count**, so a six-row table that shipped one row passes; compare it against a MEASURED number. **`grep -c` exits 1 on zero matches**, so it is a gate only when the wanted count is >= 1, and `n=$(… | grep -c X) && test "$n" -eq 0` can never pass. **`|| true`, `2>/dev/null` and a trailing `; echo` substitute a success signal** for a real one. **An unanchored `-run` also runs `TestXFoo`, and `go test -run '<nonexistent>'` prints PASS and exits 0.** And the one no amount of shape-checking catches: **a gate citing a test that ALREADY EXISTS passes whether or not the task does its work** — the defect is the referent, not the form, so a deliberately modified test is proved only by planting a defect in the new code and showing that test fail. *Why this is a rule: Story 2.2 shipped eighteen such gates — including the one local gate that stands in for all of CI while it is on hold, and a nine-hour run that exited 0 when it failed — AFTER fourteen adversarial review rounds ended clean, because review reads claims and code and not the shell mechanics of the gate lines. That needs a checker: `qa/logs/2-3/prototypes/vclint/` plus its referent check, registered as a Verification Command of the story's evidence task.*

---

## INITIALIZATION

### Configuration Loading

Load config from `{project-root}/_skad/bmm/config.yaml` and resolve:

- `project_name`, `user_name`
- `communication_language`, `document_output_language`
- `user_skill_level`
- `implementation_artifacts`
- `date` as system-generated current datetime

### Paths

- `installed_path` = `{project-root}/_skad/bmm/workflows/4-implementation/dev-tasks`
- `sprint_status` = `{implementation_artifacts}/sprint-status.yaml`
- `story_path` = `` (explicit story path; auto-discovered if empty)

### Sub-Agent Execution Context (R7, R13)

Resolve this before the first spawn for each task, and re-check it at every phase — another session may have moved a checkout in between:

1. **Repo and branch.** For every repo the task touches, run `git -C <repo> branch --show-current` and `git -C <repo> status --short`. If the checkout is on the task's branch and holds no one else's uncommitted work, use it. Otherwise create a worktree (`git -C <repo> worktree add -b <task-branch> <worktree-path> <base>`) and use that. Record `{{work_repo_path}}`, `{{work_branch}}`, and whether a path in the task file was substituted — in the orchestrator's state **and** in the task file's Task Agent Record, so a resumed session reuses the same worktree (and any recovery stash in it) instead of creating a second one.
2. **Credentials.** For each credential the task needs, record *how it is loaded* — the project's secret env file, a credential helper, a vault CLI — never the value itself.
3. **Toolchain.** The PATH entries the Verification Commands need.
4. **Build `{{execution_context}}`** — the block every sub-agent prompt begins with:

   ```
   [Execution Context]
   Repo: {{work_repo_path}}    Branch: {{work_branch}}
   (Only when substituted:) The task file names <original repo path>. Work in {{work_repo_path}} instead — it is a worktree of the same repo. Do not touch <original repo path>.
   Credentials: <for each, the command that loads it into an env var without printing it, e.g. export TOKEN=$(grep '^TOKEN=' <secret env file> | cut -d= -f2-)>. Never echo, log or paste a credential value. If a credential reads empty, stop and report that — do not report the downstream system as broken.
   Toolchain: export PATH="<toolchain dirs>:$PATH"
   Task file: {{current_task_file}}. Update only its Status field and Task Agent Record. Do NOT commit or push task files, sprint status, tracker maps or review reports — the orchestrator commits orchestration files.
   Long commands: keep every tool call under about 9 minutes — the runtime caps a call (Claude Code's Bash tool at 600 s) and silently backgrounds a longer timeout, which parks you. Repeat bounded calls until the work is done. For a gate that can take longer, run `nohup sh -c '( <gate> ) > <log> 2>&1; echo EXIT=$? >> <log>' >/dev/null 2>&1 & echo $! > <log>.pid` with <log> an absolute path unique to that gate, and poll <log> for its EXIT= line in foreground slices under 9 minutes, keeping your turn, for at most the number of slices R8 requires you to state. When that maximum is reached or the wrapper is dead (kill -0 on the pid fails), re-read <log> once more; only if it still has no EXIT= line is it a failure. Never end your turn to wait for a background job — nothing will wake you (R8).
   Verification: run each Verification Command individually; a non-zero exit is a failure; a line starting with `!` passes only when its negated command fails (R10).
   Infrastructure (R1, R2): an integration or E2E test MUST hit the project's REAL infrastructure — its actual database, auth, messaging, object store, external and AI services. A mock inside a test labelled integration or E2E is a DEFECT, not a shortcut, and the Test phase rejects it. If the real infrastructure is not wired and you cannot run the test, do NOT mock it and do NOT mark anything passed: stop and report the gap, naming what is missing. It becomes an Infrastructure Epic, which is someone's work — a mock is a silent decision to ship untested.
   Tests: a failing test is evidence about YOUR CODE. You may change a test only because the test itself was wrong or did not match the criterion it verifies — never because it was failing — and you say which of the two applied (R20). If you change a test and the code it exercises in the same breath, say so plainly; that is the shape of weakening a test to pass, and it will be read as such unless you make the case.
   Deciding: decide on your own whatever a written acceptance criterion decides, and name the criterion when you report it. If no criterion covers the choice, that silence is the thing to raise — do not resolve it by preference (R21).
   Memory: run package-level checks only; the orchestrator runs the full gate serially (R12).
   Gates (when this task adds or changes one; skip otherwise): a check with more than one condition ships with a table-driven test in the same commit, covering each condition failing alone, all passing, and every combination the code treats differently (R15). A bound computed from parts — a timeout, deadline, retry total or size limit — is checked by recomputing the sum from the parts, never against a hand-written total (R17). Register both tests as Verification Commands so the pipeline runs them.
   Iteration (when this task diagnoses against a running environment; skip otherwise): diagnose against an environment that is already up; full provisioning belongs to evidence and acceptance runs, not to testing a hypothesis (R16). Name the environment each result came from, with the commit and image or chart version it was provisioned from, and re-provision rather than report a result from an environment that no longer matches the code under test.
   ```

### OpenProject Integration

Read `openproject_id` exactly as `op-status.py` reads it (`project_id()`): `op_map_file` first, then config. Reading config alone disagrees with the tool this file calls — a project whose map carries the id but whose config does not would run every `op-status.py` command successfully while this file believed no tracker existed, and R0's mirroring would go dark for the whole story.

- `op_sync_workflow` = `{project-root}/_skad/bmm/workflows/4-implementation/openproject-sync/workflow.md`
- `op_map_file` = `{project-root}/_skad/bmm/openproject-map.yaml`
- `op_enabled` = true if `openproject_id` is present in `op_map_file` OR in config, AND `op_map_file` exists; else false

If `op_enabled` is false: the `op_enabled`-gated sync steps are skipped, and **say so once, out loud, at the start of the run**, naming which of the two was missing. The inline `tag="op-sync"` commands are not gated — they will run, fail because `op-status.py` cannot resolve a project id, and be logged and swallowed like any other OP failure. That is loud enough to act on and must not be made quiet. A pipeline that mirrors nothing looks exactly like a pipeline whose tracker agrees with it, and R0 is the rule that silence is not agreement.

### Autonomy Mode

Read `autonomy_mode` from config or user invocation argument. Valid values:

| Mode               | Behavior                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------- |
| `implement-only`   | Run Phase 1 (implement) only per task; no auto review/test                                          |
| `halt-after-story` | **(Default)** Pause after all tasks in a story are passed, awaiting human approval before advancing |
| `halt-on-high`     | Pause only when Phase 2 review finds a High-severity issue                                          |
| `full-hands-off`   | Run to completion (or failure) without pausing                                                      |

If `autonomy_mode` is not set, default to `halt-after-story`.

### Stall Detection Settings

Base thresholds (adjusted per task `Stall Profile`):

| Stall Profile          | `stall_warn` | `stall_kill` | Use Case                                                                      |
| ---------------------- | ------------ | ------------ | ----------------------------------------------------------------------------- |
| `file-heavy` (default) | 10 min       | 20 min       | Code writing, unit tests — frequent file writes expected                      |
| `api-heavy`            | 20 min       | 40 min       | MCP calls, API integrations, infra validation — long periods without file I/O |
| `mixed`                | 15 min       | 30 min       | Both file writes and API calls                                                |

Config overrides (`stall_warn_minutes`, `stall_kill_minutes`) take precedence over profile defaults.

### Multi-Signal Activity Detection

A sub-agent is considered **alive** if ANY of these signals are true:

| Signal                      | What It Detects                                    | How to Check                                                   |
| --------------------------- | -------------------------------------------------- | -------------------------------------------------------------- |
| **TaskOutput growth**       | Agent produced new output (tool results, text)     | `TaskOutput(agent_id)` length increased since last poll        |
| **Active child processes**  | Agent is running tools (curl, python3, node, etc.) | `pgrep -P <agent_pid> -la` returns active children             |
| **Network socket activity** | Agent is making API/MCP calls                      | `ss -tnp \| grep -c <agent_pid>` shows established connections |

The orchestrator only declares a stall when **ALL signals are negative** for the full `stall_kill` duration.

Override base thresholds via config or invocation args if needed.

---

## EXECUTION

<workflow>
  <critical>NEVER advance to the next task until the current task has Status = passed in its task file — except a parallel pipeline started under step 3's R9 conditions, for a task that does not depend on the current one</critical>
  <critical>NEVER modify test assertions or test goals to make a test pass — only fix production code</critical>
  <critical>Re-read task file Status at the start of every phase — never assume state from memory</critical>
  <critical>Every retry counter is persisted where its phase records it — {{retry_count}}, {{review_retry_count}} and {{test_retry_count}} in the task file's Task Agent Record, {{boundary_retry_count}} in the story file's Dev Agent Record — and written back at EVERY change, not only where it is first read. A counter that lives only in this session's memory silently grants a fresh budget to the next one, which is the failure the bound exists to prevent</critical>
  <critical>If a sub-agent stalls: git stash uncommitted changes, kill sub-agent, restart with Recovery Context</critical>
  <critical>Tests are the source of truth — failing tests identify what production code must be fixed</critical>
  <critical>Execute ALL steps in exact order; do NOT skip steps</critical>
  <critical>Before EVERY HALT in this workflow: stop every other running pipeline's sub-agents and background jobs, or record which are still running and where their logs are (R9) — a HALT ends the run and nothing else will supervise them</critical>

  <step n="1" goal="Find current position in sprint" tag="sprint-status">
    <check if="{{story_path}} is provided">
      <action>Read COMPLETE story file at {{story_path}}</action>
      <action>Extract story_key from filename or metadata</action>
      <action>Verify story Dev Notes contains a '### Task Files' subsection — HALT if not (run create-tasks first)</action>
      <goto anchor="task_discovery" />
    </check>

    <check if="{{sprint_status}} file exists">
      <critical>Read COMPLETE sprint-status.yaml from start to end to preserve order</critical>
      <action>Load FULL file: {{sprint_status}}</action>
      <action>Parse development_status section completely</action>

      <!-- An epic left behind. On a RESUME nothing below is epic-scoped: a session that died after an
           epic's last story reached `review` would pick up the next epic's first story here and the
           epic it left would never be gated. So look back before looking forward. -->
      <action>For each epic in sprint-status with no `<epic>-acceptance: done` row, in order: if it HAS at least one story and every one of them is at a terminal state (`review`, `done`) with none actionable, its acceptance gate has not run. An epic with no stories at all is not gated — it is a planning defect: say so and move past it rather than sending it into a gate whose rollup can only produce orphans, which would deadlock this epic and every later one behind it. Set {{current_epic}} to the FIRST such epic and go to the gate before starting any story of a later one.</action>
      <check if="such an epic was found">
        <output>⏮️ Epic {{current_epic}} finished its stories but never passed its acceptance gate — running it before anything newer.</output>
        <goto anchor="epic_acceptance">Gate the finished epic first</goto>
      </check>

      <!-- Look for in-progress story first (resume case) -->
      <action>Find FIRST entry matching pattern number-number-name where status = "in-progress"</action>
      <check if="in-progress story found">
        <action>Use that story as {{story_key}} — this is a resume</action>
        <action>Read that story's sprint-status entry for its current_task inline comment, in the format step 2 defines, and resume every task it lists, reusing the worktree recorded in each task file</action>
        <output>⏯️ Resuming story {{story_key}}</output>
        <goto anchor="task_discovery" />
      </check>

      <!-- Else find next ready-for-dev story -->
      <action>Find FIRST entry matching pattern number-number-name where status = "ready-for-dev"</action>
      <check if="ready-for-dev story found">
        <action>Use that story as {{story_key}}</action>
        <goto anchor="task_discovery" />
      </check>

      <check if="no in-progress or ready-for-dev story found">
        <!-- Check if there's a backlog story we can auto-create -->
        <action>Find FIRST entry matching pattern number-number-name where status = "backlog"</action>
        <check if="backlog story found">
          <output>📋 No ready-for-dev stories, but found backlog story {{backlog_story_key}}. Auto-creating story file and task files...</output>
          <action>Read fully and follow: `{project-root}/_skad/bmm/workflows/4-implementation/create-story/workflow.md`</action>
          <note>create-story will auto-discover the first backlog story from sprint-status.yaml, generate the comprehensive story file, and auto-chain into create-tasks to produce self-contained atomic task files. After completion, dev-tasks resumes from step 1.</note>
          <goto step="1">Re-discover now that story and tasks exist</goto>
        </check>
        <check if="no backlog story found either">
          <output>📋 No actionable stories found in sprint-status.yaml — all stories are in-progress, review, or done.

            **Options:**
            1. Specify a story file path directly
            2. Check sprint-status for current state
          </output>
          <ask>Provide a story file path or check sprint-status:</ask>
          <action>Handle user response and set {{story_path}} or HALT as appropriate</action>
        </check>
      </check>
    </check>

    <check if="{{sprint_status}} file does NOT exist">
      <ask>No sprint-status.yaml found. Please provide the full path to the story file to implement:</ask>
      <action>Store user-provided path as {{story_path}}</action>
      <goto anchor="task_discovery" />
    </check>

    <anchor id="task_discovery" />
    <action>Find story file in {implementation_artifacts} using pattern: {{story_key}}.md</action>
    <action>Read COMPLETE story file</action>
    <action>Verify Dev Notes contains '### Task Files' subsection</action>
    <check if="'### Task Files' subsection is missing">
      <output>⚠️ Story {{story_key}} has no task files. Auto-generating self-contained atomic task files...</output>
      <action>Set {{story_path}} = path to current story file</action>
      <action>Read fully and follow: `{project-root}/_skad/bmm/workflows/4-implementation/create-tasks/workflow.md`</action>
      <note>create-tasks will atomize the story into self-contained task files with all architecture context, code patterns, and verification commands inlined. Sub-agents can then execute each task with zero starting context.</note>
      <action>After create-tasks completes, re-read the story file to pick up the newly added Task Files subsection</action>
    </check>

    <action>Extract all task file paths from markdown links in the '### Task Files' subsection</action>
    <action>For each task file: read its Status field</action>
    <action>Find FIRST task file where Status is NOT 'passed'</action>
    <action>Set {{current_task_file}} = path to that task file</action>
    <action>Set {{current_task_file_basename}} = the file name of {{current_task_file}} WITH its `.md` extension (e.g. `task-2e-ticketing-gate-on-buildonesink.md`), and {{current_task_stem}} = that name WITHOUT `.md` (e.g. `task-2e-ticketing-gate-on-buildonesink`). Re-derive both whenever {{current_task_file}} changes.</action>
    <action>Set {{total_tasks}} = total count of task files listed</action>
    <action>Set {{passed_tasks}} = count of task files with Status = 'passed'</action>

    <check if="ALL task files have Status = 'passed'">
      <goto step="7">Story complete — run story boundary sequence</goto>
    </check>

    <output>📋 **Dev Tasks: {{story_key}}**
      Progress: {{passed_tasks}} / {{total_tasks}} tasks passed
      Next task: {{current_task_file}}
      Autonomy mode: {{autonomy_mode}}
    </output>

  </step>

  <step n="2" goal="Update sprint status to in-progress" tag="sprint-status">
    <note>**The `current_task` comment format.** This is its one definition; the sprint-status template, the sprint-status generators and every other step of this workflow refer to it. The comment sits on the story's own development_status line: `# current_task: &lt;entry&gt;[, &lt;entry&gt;…] [(&lt;note&gt;)]`.
      - Each entry is a running task's {{current_task_stem}}: its task file name WITHOUT `.md` and without a path, e.g. `task-2e-ticketing-gate-on-buildonesink`.
      - Several running tasks (parallel pipelines, R9) are separated by `, ` (a comma and one space), one entry per running pipeline.
      - An optional parenthetical note may follow the list after one space, e.g. `# current_task: task-2e-ticketing-gate-on-buildonesink, task-2f-audit-sink-retry (parallel; 2f in worktree ent-2f)`. The note is for people: a resume ignores it and takes each task's worktree from its task file.
      To read the comment, take the text after `current_task: `, drop a trailing parenthetical note, and split the rest on `, `.</note>
    <check if="{{sprint_status}} file exists">
      <action>Load FULL file: {{sprint_status}}</action>
      <action>Find development_status[{{story_key}}]</action>
      <check if="current status == 'ready-for-dev'">
        <action>Update status to "in-progress"</action>
        <action>Add comment on same line: # current_task: {{current_task_stem}}</action>
        <action>Update last_updated to current date</action>
        <output>🚀 Story {{story_key}}: ready-for-dev → in-progress</output>
      </check>
      <check if="current status == 'in-progress'">
        <action>Update the current_task comment to reflect {{current_task_stem}} — add or replace only this pipeline's entry; keep the entries of other running pipelines (R9)</action>
        <output>⏯️ Resuming story {{story_key}} at task {{current_task_file_basename}}</output>
      </check>
    </check>
  </step>

  <step n="2b" goal="OpenProject: Bootstrap Task WPs for current story" tag="op-sync">
    <check if="{{op_enabled}} == true">
      <action>Read COMPLETE {{op_sync_workflow}}</action>
      <action>Execute ACTION: bootstrap-tasks with:
        - story_key = {{story_key}}
        - project_root = {project-root}
      </action>
      <critical>OP sync failures must NEVER halt the dev-tasks pipeline. If the sync workflow returns a warning, log it and continue.</critical>
    </check>
  </step>

  <step n="3" goal="Dependency check for current task">
    <action>Read COMPLETE task file: {{current_task_file}}</action>
    <action>Extract 'Requires:' field from Dependency Order section</action>
    <action>Expand it into an explicit set of task IDs (R11): expand ranges ("2a–2g" → 2a, 2b, … 2g; "Tasks 1–7" → 1 through 7, including any lettered splits of those numbers), split lists joined by commas and "and", and resolve prose ("all implementation tasks") against the Task Files list. When prose is qualified by a range ("All implementation tasks (1 through 5)"), the set is the union of both readings — the conservative one. If the line cannot be expanded unambiguously, the set is every task listed before this one. Never match single task IDs out of the line.</action>
    <check if="the expanded set contains one or more tasks">
      <action>For each task in the expanded set: read its task file and check Status field</action>
      <check if="any required task does NOT have Status = 'passed'">
        <output>🚫 Dependency violation: {{current_task_file}} requires {{unmet_dependency}} which is not yet passed.

          This indicates a task ordering issue in the task files. Tasks must be ordered so that no task depends on a future (uncompleted) task.

          **Action required:** Review the Task Files list in the story Dev Notes and ensure tasks are ordered correctly. Run `create-tasks` again if the ordering is wrong.
        </output>
        <action>HALT</action>
      </check>
    </check>
    <!-- R19: cross-story and cross-epic hard dependencies. `Requires:` above covers task IDs inside this story; this covers item keys outside it, and they are read separately on purpose. -->
    <action>Extract `Depends on:` — or `Blocked on:`, its older spelling, whose entries are all hard — from the same Dependency Order section. A task file carrying NEITHER is incomplete: its story carries one and create-tasks repeats it here, so go back rather than assuming `none`. A missing field read as `none` is a check that passed having looked at nothing.</action>
    <check if="it names one or more `hard:` entries">
      <action>For each hard entry, establish that its acceptance gate PASSED, not merely that the item exists — existence is what `Requires:` checks, and it is not the same claim:
        - an EPIC key (`epic-N`): sprint-status must carry `epic-N-acceptance: done`, which only the epic acceptance gate writes.
        - a STORY key: that story's status must be `done`, which this pipeline now writes only after its acceptance criteria passed against a DEPLOYED OR RUNNING system (the story acceptance gate in step 7). **`review` is not enough** — it means a PR is open and says nothing about anything having been verified.
          **Stories closed before this project adopted the acceptance gate are `done` with no environment recorded, and that is not their fault.** Blocking on them would stop every project that ever closed a story the old way, which is every project. So: a `done` whose story file records an acceptance environment is PROVEN; a `done` without one is **grandfathered** — proceed, and say in the run's output which dependencies were accepted on that basis and how many. It is a real gap in the evidence, not a reason to halt, and counting it is what stops it becoming permanent. A story closed AFTER the gate exists and still missing its record is a defect, not a grandfathered case: the gate writes that record, so its absence means the gate did not run.
        - a FEATURE key: its feature-level acceptance record, where the project uses that level.
      </action>
      <check if="any hard dependency is unmet or unproven">
        <output>⛔ {{current_task_file_basename}} depends on {{unmet_hard_dependency}}, whose acceptance gate has not passed. Not starting it.</output>
        <action>FIRST, write the local status: `development_status[{{story_key}}]` → `blocked` in sprint-status.yaml, and remove that entry's `current_task` comment. sprint-status.yaml is the file discovery reads, and step 1 looks for `in-progress` BEFORE anything else — a story left `in-progress` here is resumed by the next `goto step="1"` or by the next run, whatever the tracker says. Local first, then the tracker: if the run dies between the two, a story that is locally `blocked` and untouched in the tracker is caught by `op-status.py check` as drift, while the reverse is invisible to it and silently resumes.</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} blocked --note "hard dependency {{unmet_hard_dependency}} not accepted"` (R0)</action>
        <action>BLOCK THE LANE, do not HALT (R18): this is about one item's prerequisites, not about state nobody can describe. Stop only this story's sub-agents, report the blocked count, and `goto anchor="next_story"` for work that does not depend on it.</action>
        <goto anchor="next_story">Blocked on an unmet hard dependency; pick up independent work.</goto>
      </check>
    </check>
    <output>✅ Dependencies satisfied for {{current_task_file_basename}}</output>
    <action>Parallel candidates (R9): a later task may start alongside this one only if no running pipeline already owns it, its own expanded Requires set is entirely `passed`, it shares no file in 'Exact Files to Touch' with any running task, and it works in a separate repo or worktree. Otherwise it waits its turn. A task that does start runs steps 4–6 as its own pipeline: every per-task variable in those steps — {{current_task_file}}, {{execution_context}}, agent IDs, {{retry_count}}, {{review_retry_count}}, {{test_retry_count}}, stall counters, and every value derived from the task file (its basename and stem, and so every tracker update made with them) — is held per pipeline, never shared. Record every running task in the sprint-status `current_task` comment, in the format step 2 defines. Step 7 never starts a second pipeline for a task already in flight, and its story boundary is reached only when every task is `passed`.</action>

  </step>

  <step n="4" goal="Phase 1 — Implement" tag="implement">
    <critical>Fix code to meet tests — NEVER modify test assertions to force a pass</critical>

    <action>Read current task file Status field</action>
    <!-- Status routing. A resumed run routes by the Status it finds; every value in the Task Status Reference has exactly one route, and Phase 1 runs only for 'ready-for-task'. The routes for 'failed', a resumed 'in-dev' and an unrecognised value are orchestrator defaults the project owner may override. -->
    <check if="task Status == 'passed'">
      <goto step="6">Task already complete — step 6 advances past it without testing it again</goto>
    </check>
    <check if="task Status == 'failed'">
      <output>🛑 {{current_task_file_basename}} has Status 'failed': it failed in an earlier run and needs a human. dev-tasks never overwrites a `failed` marker.
        Investigate the failure, then reset the task's Status explicitly (for example to `ready-for-task`) before re-running dev-tasks.
      </output>
      <action>HALT</action>
    </check>
    <check if="task Status is not one of: ready-for-task, in-dev, in-dev-complete, in-review, in-test (a missing or empty Status included)">
      <output>🛑 {{current_task_file_basename}} has an unrecognised Status '{{task_status}}'. The valid values are listed in the Task Status Reference.
        Correct the Status by hand before re-running dev-tasks; dev-tasks does not guess which phase the task is in.
      </output>
      <action>HALT</action>
    </check>
    <action>Set {{retry_count}} = this task's Phase 1 attempt count recorded in the task file's Task Agent Record, or 0 when it records none — this task's Phase 1 attempt counter; stall respawns and early-stop resumes both count toward it (R8). Write it back to the Task Agent Record whenever it changes, so an orchestrator that restarts resumes the count instead of granting a fresh budget.</action>

    <action>Resolve {{execution_context}} for this task (see *Sub-Agent Execution Context*); reuse the worktree recorded in the task file's Task Agent Record if there is one</action>

    <!-- Resolve stall thresholds from task Stall Profile — before any route that monitors an agent, including a resume at Phase 2 or 3 -->
    <action>Read "Stall Profile:" field from current task file (default: "file-heavy" if absent)</action>
    <action>Set {{effective_stall_warn}} and {{effective_stall_kill}} based on profile:
      - file-heavy: stall_warn=10, stall_kill=20
      - api-heavy:  stall_warn=20, stall_kill=40
      - mixed:      stall_warn=15, stall_kill=30
      If config overrides (stall_warn_minutes / stall_kill_minutes) are set, use those instead.
    </action>

    <check if="autonomy_mode == 'implement-only' AND task Status is 'in-review' or 'in-test'">
      <output>ℹ️ {{current_task_file_basename}} is already implemented (Status '{{task_status}}'); autonomy mode 'implement-only' runs no review or test. Stopping.</output>
      <action>HALT</action>
    </check>
    <check if="task Status == 'in-dev-complete'">
      <goto anchor="implement_complete">Implementation already finished — hand it to review</goto>
    </check>
    <check if="task Status == 'in-review'">
      <goto step="5">Resume at Phase 2 — do not re-implement or overwrite Status</goto>
    </check>
    <check if="task Status == 'in-test'">
      <goto step="6">Resume at Phase 3 — do not re-implement or overwrite Status</goto>
    </check>
    <action>Liveness of a recorded agent: ask the runtime about that agent ID (read its output or status by ID). An agent the runtime does not know — an ID from a session that has ended, or a runtime that cannot answer — counts as NOT running. Never infer that an agent is alive from the task file alone; the routes below then HALT for a human instead of starting a second agent beside a possibly live one.</action>
    <check if="task Status == 'in-dev' (a resumed run: this run has not yet spawned an implementation agent for this task)">
      <check if="the task file's Task Agent Record or the orchestrator's state names an implementation agent ID, AND the runtime reports that agent still running">
        <action>Set {{implement_agent_id}} = that agent ID</action>
        <output>⏯️ Re-attaching to running implementation agent {{implement_agent_id}} for {{current_task_file_basename}} — no second implementer is spawned</output>
        <goto anchor="implement_monitor">Monitor the running agent with fresh stall counters</goto>
      </check>
      <output>🛑 {{current_task_file_basename}} was interrupted mid-implementation: its Status is 'in-dev' and no still-running implementation agent is recorded for it.
        Its worktree may hold partial work. Inspect the worktree named in the task file's Task Agent Record, including `git stash list` there, then reset the Status explicitly (for example to `ready-for-task`) before re-running dev-tasks. dev-tasks never spawns a second implementer beside one that may still be live.
      </output>
      <action>HALT</action>
    </check>
    <!-- Status == 'ready-for-task': start Phase 1 -->
    <action>Update task file Status field: → `in-dev`</action>
    <action tag="op-sync">Mirror it: `python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} in-dev` (R0). An OP failure logs and continues — it must never halt the pipeline — but it is reported, never swallowed.</action>
    <output>🔨 **Phase 1: Implement** — {{current_task_file_basename}}
      Spawning implementation sub-agent...
    </output>

    <action>Spawn background sub-agent with the following prompt:
      ```
      {{execution_context}}

      You are implementing a single atomic task. Load and follow the task file EXACTLY:
      Task file: {{current_task_file}}

      Instructions:
      - This task file is your ONLY source of truth. Follow it completely.
      - Use ONLY the Embedded Architecture Context in the task file — do not load external architecture docs.
      - Modify ONLY the files listed in 'Exact Files to Touch'.
      - Follow all 'DO NOT' prohibitions without exception.
      - Run the Verification Commands at the end, each individually as the Execution Context describes. Every one must pass (exit 0; a line starting with `!` passes only when its negated command fails).
      - If a verification command fails: fix PRODUCTION CODE ONLY. NEVER alter test assertions or test goals.
      - When ALL Completion Checklist items are satisfied AND all Verification Commands pass: update the task file Status → 'in-dev-complete' and fill in Task Agent Record.
      - HALT if: new dependencies are needed, 3 consecutive implementation failures occur, or required config is missing.
      ```
    </action>
    <action>Store sub-agent ID as {{implement_agent_id}}, and record it in the orchestrator's state and in the task file's Task Agent Record, so a resumed run can re-attach to it instead of spawning a second implementer</action>

    <!-- Multi-signal stall monitoring loop -->
    <anchor id="implement_monitor" />
    <action>Set {{last_output_len}} = 0, {{stall_count}} = 0</action>
    <loop until="sub-agent completes OR stall confirmed">
      <action>Wait {{effective_stall_warn}} minutes, in slices under 9 minutes each (R8)</action>

      <!-- Signal 1: TaskOutput growth -->
      <action>Read TaskOutput({{implement_agent_id}})</action>
      <action>Set {{current_output_len}} = length of output so far</action>
      <action>Set {{output_grew}} = ({{current_output_len}} > {{last_output_len}})</action>

      <!-- Signal 2: Active child processes (curl, python3, node, etc.) -->
      <action>Run: pgrep -la "curl|python3|node|npm|npx|pytest|jest" 2>/dev/null | wc -l</action>
      <action>Set {{has_active_children}} = (result > 0)</action>

      <!-- Signal 3: Network socket activity -->
      <action>Run: ss -tnp 2>/dev/null | grep -c "ESTAB" || echo "0"</action>
      <action>Set {{has_network_activity}} = (result > 0)</action>

      <!-- Evaluate: agent is alive if ANY signal is positive -->
      <check if="{{output_grew}} OR {{has_active_children}} OR {{has_network_activity}}">
        <action>Set {{last_output_len}} = {{current_output_len}}, {{stall_count}} = 0</action>
        <check if="NOT {{output_grew}} AND ({{has_active_children}} OR {{has_network_activity}})">
          <output>⏳ No output growth but agent is active (child processes: {{has_active_children}}, network: {{has_network_activity}}). Stall timer reset.</output>
        </check>
      </check>

      <!-- All signals negative — possible stall -->
      <check if="NOT {{output_grew}} AND NOT {{has_active_children}} AND NOT {{has_network_activity}}">
        <action>Increment {{stall_count}}</action>
        <output>⏳ No activity detected on any signal ({{stall_count * effective_stall_warn}} min). Monitoring for stall...</output>
        <check if="{{stall_count}} * {{effective_stall_warn}} >= {{effective_stall_kill}}">
          <action>TaskStop({{implement_agent_id}})</action>
          <output>🔴 Implementation sub-agent stalled (all signals negative for {{effective_stall_kill}} min). Initiating recovery...</output>
          <goto anchor="implement_recovery" />
        </check>
      </check>
    </loop>
    <goto anchor="implement_result">The loop ended without a confirmed stall — evaluate the sub-agent's result; recovery runs only from the stall path above</goto>

    <!-- Recovery on stall -->
    <anchor id="implement_recovery" />
    <action>Run: git -C {{work_repo_path}} status (check for uncommitted partial changes from failed agent — in the task's own checkout or worktree, never a shared one; R13)</action>
    <action>If uncommitted changes exist: run git -C {{work_repo_path}} stash with message "dev-tasks recovery: stalled on {{current_task_file_basename}}"</action>
    <action>Set {{retry_count}} = ({{retry_count}} or 0) + 1. Write the new value back to the task file's Task Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
    <check if="{{retry_count}} > 2">
      <output>🚫 Implementation of {{current_task_file_basename}} failed after 2 retries. Manual intervention required.
        Update task file Status → 'failed' and investigate before re-running dev-tasks.
      </output>
      <action>Update task file Status → 'failed'</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
      <action>HALT</action>
    </check>

    <action>Spawn new sub-agent with the same prompt PLUS a Recovery Context section:
      ```
      [Recovery Context]
      Previous agent stalled or failed (attempt {{retry_count}} of 2).
      Stashed changes message: "dev-tasks recovery: stalled on {{current_task_file_basename}}"
      Check git stash list. If stash exists, review stashed diff before deciding whether to pop or discard.
      Start fresh from the beginning of the task file unless the stashed changes are correct and complete.
      ```
    </action>
    <action>Store new sub-agent ID as {{implement_agent_id}}, replacing the recorded ID in the orchestrator's state and the Task Agent Record</action>
    <goto anchor="implement_monitor">Monitor the replacement sub-agent with fresh stall counters</goto>

    <!-- Success path -->
    <anchor id="implement_result" />
    <!-- Early stop is not a stall (R8) -->
    <check if="sub-agent ended its turn while task file Status is still 'in-dev' (e.g. it said it is waiting on a background job, or it asked a question)">
      <action>Set {{retry_count}} = {{retry_count}} + 1 — a resume counts toward the same limit as a stall respawn (R8). Write the new value back to the task file's Task Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
      <check if="{{retry_count}} > 2">
        <output>🚫 Implementation of {{current_task_file_basename}} failed after 2 retries (the last attempt stopped before finishing). Manual intervention required.
          Update task file Status → 'failed' and investigate before re-running dev-tasks.
        </output>
        <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
        <action>HALT</action>
      </check>
      <action>Resume THE SAME agent ({{implement_agent_id}}) with a message: answer its question, or tell it to run the command in the foreground under a timeout and carry on. Do NOT spawn a second implementation agent beside it.</action>
      <goto anchor="implement_monitor">Monitor the resumed agent with fresh stall counters</goto>
    </check>

    <anchor id="implement_complete" />
    <check if="task file Status == 'in-dev-complete' (the sub-agent completed successfully, or a resumed run found the implementation already finished)">
      <action>Update task file Status → `in-review`</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} in-review` (R0)</action>
      <output>✅ Phase 1 complete: {{current_task_file_basename}} → in-review</output>
    </check>

    <check if="autonomy_mode == 'implement-only'">
      <output>ℹ️ Autonomy mode is 'implement-only'. Stopping after implementation phase.
        Run dev-tasks again to continue with review and test phases.
      </output>
      <action>HALT</action>
    </check>

  </step>

  <step n="5" goal="Phase 2 — Lightweight Self-Review" tag="review">
    <action>Read current task file Status field</action>
    <check if="task Status != 'in-review'">
      <output>🛑 Phase 2 expects Status 'in-review' for {{current_task_file_basename}}, found '{{task_status}}'. A phase is never skipped on an unexpected Status.
        Check the task file and correct its Status before re-running dev-tasks.
      </output>
      <action>HALT</action>
    </check>
    <action>Set {{review_retry_count}} = this task's Phase 2 attempt count recorded in the task file's Task Agent Record, or 0 when it records none — stall respawns and early-stop resumes of the review, fix and re-review sub-agents all count toward it (R8). Write it back to the Task Agent Record whenever it changes, so a restart resumes the count.</action>
    <check if="the task file's Task Agent Record or the orchestrator's state names a review, fix or re-review agent for this task that the runtime reports still running (a resumed run), liveness as step 4 defines">
      <check if="it is the review agent">
        <action>Set {{review_agent_id}} = that agent ID</action>
        <output>⏯️ Re-attaching to running review agent {{review_agent_id}} for {{current_task_file_basename}} — no second review agent is spawned</output>
        <goto anchor="review_monitor">Monitor the running agent with fresh stall counters</goto>
      </check>
      <output>🛑 {{current_task_file_basename}}: a full-hands-off fix or re-review agent from an interrupted run is still running. dev-tasks does not start a second agent beside it.
        Let that agent finish or stop it, then re-run dev-tasks.
      </output>
      <action>HALT</action>
    </check>
    <check if="the Task Agent Record names a review agent for this task that the runtime reports is NOT running — an earlier run died before Phase 2 finished">
      <action>Set {{review_retry_count}} = {{review_retry_count}} + 1 — restarting a phase whose agent died counts as a retry, exactly as a stall respawn does (R8). Write the new value back to the task file's Task Agent Record now, not at the next read.</action>
      <check if="{{review_retry_count}} > 2">
        <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
        <output>🚫 Phase 2 of {{current_task_file_basename}} has been restarted after a dead agent 2 times. Manual intervention required.</output>
        <action>HALT</action>
      </check>
      <action>Before spawning a replacement, check {{work_repo_path}} for uncommitted partial work the dead agent left and stash it, as the Phase 1 recovery does (R13) — a review agent edits production code too</action>
    </check>

    <output>🔍 **Phase 2: Review** — {{current_task_file_basename}}
      Spawning self-review sub-agent...
    </output>

    <action>Spawn background sub-agent with the following prompt:
      ```
      {{execution_context}}

      You are performing a focused self-review of a just-implemented task. Your job is to verify correctness and quality.

      Task file: {{current_task_file}}

      Review against the task file's Completion Checklist:
      - Are ALL checklist items satisfied? (verify each one independently)
      - Do the modified files match ONLY the 'Exact Files to Touch' list?
      - Does the implementation satisfy the stated acceptance criteria references?
      - Are there any DO NOT violations?
      - Is there any dead code, debug output, or commented-out test logic?
      - Does each Verification Command fail when the defect it guards is present? Test it the way the pipeline runs it — each line individually, `!` semantics (R10) — never as one `set -e` block. If a planted defect does not fail the check, the plant or the check is wrong; find out which before reporting either.
      - A finding that something is absent ("no test covers X", "not wired") is only as wide as the search behind it: search the whole package before reporting it, and quote the search.

      For each finding, classify severity:
        - High: correctness bug, AC not met, test integrity violation (test modified to pass instead of fixing code)
        - Medium: code quality, missing edge case, minor deviation from task spec
        - Low: style, naming, comment quality

      Output format:
        REVIEW RESULT: PASS | PASS-WITH-FIXES | FAIL
        Findings:
          [High] <description> — <file:line>
          [Medium] <description>
          [Low] <description>

      If PASS-WITH-FIXES: fix all Medium/Low issues in production code now, then output REVIEW RESULT: PASS.
      If FAIL (any High finding): output REVIEW RESULT: FAIL with full details. Do NOT attempt to fix.
      NEVER alter test assertions to resolve a finding — only fix production code.
      ```
    </action>
    <action>Store sub-agent ID as {{review_agent_id}}, and record it in the orchestrator's state and in the task file's Task Agent Record, so a resumed run can re-attach to it instead of spawning a second review agent</action>

    <!-- Multi-signal stall monitoring (same pattern as Phase 1) -->
    <anchor id="review_monitor" />
    <action>Set {{last_output_len}} = 0, {{stall_count}} = 0</action>
    <loop until="sub-agent completes OR stall confirmed">
      <action>Wait {{effective_stall_warn}} minutes, in slices under 9 minutes each (R8)</action>
      <action>Read TaskOutput({{review_agent_id}})</action>
      <action>Set {{current_output_len}} = length of output</action>
      <action>Set {{output_grew}} = ({{current_output_len}} > {{last_output_len}})</action>
      <action>Check child processes: pgrep -la "curl|python3|node" 2>/dev/null | wc -l</action>
      <action>Check network: ss -tnp 2>/dev/null | grep -c "ESTAB" || echo "0"</action>

      <check if="any signal positive (output grew OR active children OR network)">
        <action>Set {{last_output_len}} = {{current_output_len}}, {{stall_count}} = 0</action>
      </check>
      <check if="all signals negative">
        <action>Increment {{stall_count}}</action>
        <check if="{{stall_count}} * {{effective_stall_warn}} >= {{effective_stall_kill}}">
          <action>TaskStop({{review_agent_id}})</action>
          <action>Set {{review_retry_count}} = {{review_retry_count}} + 1. Write the new value back to the task file's Task Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
          <check if="{{review_retry_count}} > 2">
            <action>Update task file Status → 'failed'</action>
            <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
            <output>🚫 Review phase of {{current_task_file_basename}} stalled after 2 retries (all signals negative). Manual intervention required.</output>
            <action>HALT</action>
          </check>
          <output>⚠️ Review sub-agent stalled (all signals negative). Re-spawning (attempt {{review_retry_count}} of 2)...</output>
          <action>Spawn fresh review sub-agent with same prompt</action>
          <action>Store new sub-agent ID as {{review_agent_id}}, replacing the recorded ID in the orchestrator's state and the Task Agent Record</action>
          <goto anchor="review_monitor">Monitor the replacement sub-agent with fresh stall counters</goto>
        </check>
      </check>
    </loop>

    <!-- Early stop is not a stall (R8) -->
    <check if="sub-agent ended its turn without a final 'REVIEW RESULT: PASS' or 'REVIEW RESULT: FAIL' (e.g. it said it is waiting on a background job, asked a question, or stopped after PASS-WITH-FIXES without reporting PASS)">
      <action>Set {{review_retry_count}} = {{review_retry_count}} + 1 — a resume counts toward the same limit as a stall respawn (R8). Write the new value back to the task file's Task Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
      <check if="{{review_retry_count}} > 2">
        <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
        <output>🚫 Review phase of {{current_task_file_basename}} stopped before finishing after 2 retries. Manual intervention required.</output>
        <action>HALT</action>
      </check>
      <action>Resume THE SAME agent ({{review_agent_id}}) with a message: answer its question, or tell it to run the command in the foreground under a timeout and carry on. Do NOT spawn a second review agent beside it.</action>
      <goto anchor="review_monitor">Monitor the resumed agent with fresh stall counters</goto>
    </check>

    <action>Read review output for REVIEW RESULT</action>

    <check if="REVIEW RESULT == 'PASS'">
      <action>Update task file Status → `in-test`</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} in-test` (R0)</action>
      <output>✅ Phase 2 complete: {{current_task_file_basename}} → in-test</output>
    </check>

    <check if="REVIEW RESULT == 'FAIL' (High findings present)">
      <check if="autonomy_mode == 'halt-after-story' OR autonomy_mode == 'halt-on-high'">
        <output>🛑 **Review FAILED — High-severity findings require human review**

          Task: {{current_task_file_basename}}
          {{review_findings}}

          Fix the production code issues listed above, then re-run dev-tasks to continue.
          (Remember: NEVER modify test assertions — fix only production code.)
        </output>
        <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
        <action>HALT</action>
      </check>
      <check if="autonomy_mode == 'full-hands-off'">
        <output>⚠️ High-severity findings detected. Attempting auto-fix in full-hands-off mode...</output>
        <action>Spawn fix sub-agent scoped to High findings — production code only, never tests. Its prompt opens with {{execution_context}} (R7).</action>
        <action>Record the fix sub-agent's ID, and then the re-run review sub-agent's, in the orchestrator's state and the Task Agent Record as each is spawned. Monitor each with the stall detection above. Each stall respawn or early-stop resume counts toward {{review_retry_count}}; past 2 retries the task takes this phase's failure path exactly as the stall check above does.</action>
        <action>After fix: re-run review sub-agent (one retry only)</action>
        <check if="second review passes (REVIEW RESULT: PASS)">
          <action>Update task file Status → `in-test`</action>
          <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} in-test` (R0)</action>
          <output>✅ Phase 2 complete after auto-fix: {{current_task_file_basename}} → in-test</output>
        </check>
        <check if="second review still fails">
          <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
          <output>🚫 Auto-fix failed. Manual intervention required for {{current_task_file_basename}}.</output>
          <action>HALT</action>
        </check>
      </check>
    </check>

  </step>

  <step n="6" goal="Phase 3 — Test" tag="test">
    <critical>NEVER modify test assertions or test goals. If tests fail, fix production code only.</critical>

    <action>Read current task file Status field</action>
    <check if="task Status == 'passed'">
      <goto step="7">Already passed — advance with no output; this is the correct path, not a warning</goto>
    </check>
    <check if="task Status != 'in-test'">
      <output>🛑 Phase 3 expects Status 'in-test' for {{current_task_file_basename}}, found '{{task_status}}'. A phase is never skipped on an unexpected Status.
        Check the task file and correct its Status before re-running dev-tasks.
      </output>
      <action>HALT</action>
    </check>

    <action>Set {{test_retry_count}} = this task's Phase 3 attempt count recorded in the task file's Task Agent Record, or 0 when it records none. Write it back to the Task Agent Record whenever it changes, so a restart resumes the count.</action>
    <check if="the task file's Task Agent Record or the orchestrator's state names a test agent for this task that the runtime reports still running (a resumed run), liveness as step 4 defines">
      <action>Set {{test_agent_id}} = that agent ID</action>
      <output>⏯️ Re-attaching to running test agent {{test_agent_id}} for {{current_task_file_basename}} — no second test agent is spawned</output>
      <goto anchor="test_monitor">Monitor the running agent with fresh stall counters</goto>
    </check>
    <check if="the Task Agent Record names a test agent for this task that the runtime reports is NOT running — an earlier run died before Phase 3 finished">
      <action>Set {{test_retry_count}} = {{test_retry_count}} + 1 — restarting a phase whose agent died counts as a retry, exactly as a stall respawn does (R8). Write the new value back to the task file's Task Agent Record now, not at the next read.</action>
      <check if="{{test_retry_count}} > 2">
        <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
        <output>🚫 Phase 3 of {{current_task_file_basename}} has been restarted after a dead agent 2 times. Manual intervention required.</output>
        <action>HALT</action>
      </check>
      <action>Before spawning a replacement, check {{work_repo_path}} for uncommitted partial work the dead agent left and stash it, as the Phase 1 recovery does (R13) — a test agent edits production code too</action>
    </check>

    <output>🧪 **Phase 3: Test** — {{current_task_file_basename}}
      Spawning test sub-agent...
    </output>

    <anchor id="test_run" />
    <action>Spawn background sub-agent with the following prompt:
      ```
      {{execution_context}}

      You are the test verification agent for a completed task.

      Task file: {{current_task_file}}

      Your job:
      1. Read the 'Verification Commands' section from the task file.
      2. Run EVERY verification command exactly as written, each individually (one line per invocation) — never chained into one `set -e` script. A non-zero exit is a failure; a line starting with `!` passes only when its negated command fails.
      3. For each command that exits non-zero:
         - Diagnose the failure.
         - Fix ONLY production code (source files). NEVER alter test files, test assertions, or test goals.
         - Re-run the command after fixing.
      4. If you cannot fix a failure in production code without also changing the test, output:
         TEST-INTEGRITY-HALT: <description of the conflict>
         Then STOP — do not modify any test.
      5. When ALL commands exit 0: output VERIFICATION: PASS
      6. Run the regression checks for the packages or modules this task touched to confirm no regressions. If regressions found: fix production code. Output REGRESSION: PASS when clean.
         Do NOT run the project's full memory-heavy gate (full race suite, full e2e) — the orchestrator runs it serially at the story boundary (R12).
         If a check dies with `signal: killed` or exit 137, read the memory peak before calling it a failure, and report it as a probable OOM.

      Output FINAL STATUS: PASSED only when both VERIFICATION: PASS and REGRESSION: PASS.
      ```
    </action>
    <action>Store sub-agent ID as {{test_agent_id}}, and record it in the orchestrator's state and in the task file's Task Agent Record, so a resumed run can re-attach to it instead of spawning a second test agent</action>

    <!-- Multi-signal stall monitoring -->
    <anchor id="test_monitor" />
    <action>Set {{last_output_len}} = 0, {{stall_count}} = 0</action>
    <loop until="sub-agent completes OR stall confirmed">
      <action>Wait {{effective_stall_warn}} minutes, in slices under 9 minutes each (R8)</action>
      <action>Read TaskOutput({{test_agent_id}})</action>
      <action>Set {{current_output_len}} = length of output</action>
      <action>Set {{output_grew}} = ({{current_output_len}} > {{last_output_len}})</action>
      <action>Check child processes: pgrep -la "curl|python3|node|pytest|jest" 2>/dev/null | wc -l</action>
      <action>Check network: ss -tnp 2>/dev/null | grep -c "ESTAB" || echo "0"</action>

      <check if="any signal positive (output grew OR active children OR network)">
        <action>Set {{last_output_len}} = {{current_output_len}}, {{stall_count}} = 0</action>
      </check>
      <check if="all signals negative">
        <action>Increment {{stall_count}}</action>
        <check if="{{stall_count}} * {{effective_stall_warn}} >= {{effective_stall_kill}}">
          <action>TaskStop({{test_agent_id}})</action>
          <action>git -C {{work_repo_path}} stash if uncommitted changes exist (the task's own checkout or worktree; R13)</action>
          <action>Set {{test_retry_count}} = {{test_retry_count}} + 1. Write the new value back to the task file's Task Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
          <check if="{{test_retry_count}} > 2">
            <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
            <output>🚫 Test phase stalled after 2 retries (all signals negative). Manual intervention required.</output>
            <action>HALT</action>
          </check>
          <goto anchor="test_run">Spawn the replacement there — this anchor is the spawn, so spawning here as well would start a second test agent on the same task</goto>
        </check>
      </check>
    </loop>

    <!-- Early stop is not a stall (R8) -->
    <check if="sub-agent ended its turn with none of 'FINAL STATUS: PASSED', 'TEST-INTEGRITY-HALT' or a reported failure (e.g. it said it is waiting on a background job, or it asked a question)">
      <action>Set {{test_retry_count}} = {{test_retry_count}} + 1 — a resume counts toward the same limit as a stall respawn or a failed run (R8). Write the new value back to the task file's Task Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
      <check if="{{test_retry_count}} > 2">
        <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
        <output>🚫 Test phase of {{current_task_file_basename}} stopped before finishing after 2 retries. Manual intervention required.</output>
        <action>HALT</action>
      </check>
      <action>Resume THE SAME agent ({{test_agent_id}}) with a message: answer its question, or tell it to run the command in the foreground under a timeout and carry on. Do NOT spawn a second test agent beside it.</action>
      <goto anchor="test_monitor">Monitor the resumed agent with fresh stall counters</goto>
    </check>

    <check if="sub-agent output contains 'TEST-INTEGRITY-HALT'">
      <output>🛑 **Test integrity conflict detected in {{current_task_file_basename}}**

        The test sub-agent flagged a case where fixing the failure would require modifying a test assertion.
        This indicates either:
        a) The implementation fundamentally misunderstands the acceptance criterion, OR
        b) The test was written incorrectly in create-tasks (rare)

        {{test_integrity_details}}

        **Human review required.** Do not modify tests — reassess the implementation approach.
      </output>
      <action>Update task file Status → 'failed'</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
      <action>HALT</action>
    </check>

    <check if="sub-agent output contains 'FINAL STATUS: PASSED'">
      <action>Update task file Status → `passed`</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} passed --note "<what proved it: the commands run and their result>"` (R0)</action>
      <action>Mark corresponding checkbox [x] in story file Tasks/Subtasks section</action>
      <action>Update story File List with any new/modified files from this task</action>
      <output>✅ **Task PASSED: {{current_task_file_basename}}** ({{passed_tasks + 1}} / {{total_tasks}})</output>

      <!-- OpenProject: sync task status -->
      <check if="{{op_enabled}} == true">
        <action>Read COMPLETE {{op_sync_workflow}}</action>
        <action>Execute ACTION: task-passed with:
          - story_key = {{story_key}}
          - task_file_basename = {{current_task_file_basename}}
          - project_root = {project-root}
        </action>
        <critical>OP sync failure must NOT block the pipeline. Log warning and continue.</critical>
      </check>
    </check>

    <check if="sub-agent output contains failure and no TEST-INTEGRITY-HALT">
      <action>Set {{test_retry_count}} = {{test_retry_count}} + 1. Write the new value back to the task file's Task Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
      <check if="{{test_retry_count}} > 2">
        <action>Update task file Status → 'failed'</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py task {{story_key}} {{current_task_stem}} failed --note "<why it halted>"` (R0) — a halted task shows as halted in the tracker, never as quietly open.</action>
        <output>🚫 Tests failed after 2 retries. Manual intervention required for {{current_task_file_basename}}.</output>
        <action>HALT</action>
      </check>
      <output>⚠️ Test phase failed (attempt {{test_retry_count}}). Retrying...</output>
      <goto anchor="test_run" />
    </check>

  </step>

  <step n="7" goal="Advance to next task or story boundary">
    <action>Housekeeping (R9): list running sub-agents and background shell jobs; stop any whose result is already recorded or is no longer needed. Report "N running" separately from finished history entries.</action>
    <action>Re-read ALL task files for {{story_key}} and count Status = 'passed'</action>

    <check if="remaining tasks with Status != 'passed' exist">
      <check if="every remaining task with Status != 'passed' is owned by a running pipeline (R9)">
        <action>Wait the shortest {{effective_stall_warn}} among the running pipelines (each pipeline keeps its own; the wait is taken in slices under 9 minutes — R8), running the stall checks of steps 4–6 for each; do not start another. Each pipeline's own stall_kill and retry limits bound this wait: a pipeline that exceeds them follows its own HALT path, which stops the run after the other pipelines are stopped (R9).</action>
        <goto step="7">Re-enter when a running pipeline finishes</goto>
      </check>
      <action>Set {{current_task_file}} = next task file where Status != 'passed' AND no running pipeline owns it (R9)</action>
      <action>Re-derive {{current_task_file_basename}} and {{current_task_stem}} for that task file (step 1), then update the current_task comment in sprint-status.yaml in the format step 2 defines — replace only the finished pipeline's entry with {{current_task_stem}}; keep the entries of other running pipelines (R9)</action>
      <output>➡️ Advancing to next task: {{current_task_file_basename}}</output>
      <goto step="3">Next task — dependency check</goto>
    </check>

    <check if="ALL tasks have Status = 'passed'">
      <output>🎉 All {{total_tasks}} tasks passed for story {{story_key}}!

        Running story-level adversarial code review...
      </output>
      <action>Set {{boundary_retry_count}} = the story boundary attempt count recorded in the story file's Dev Agent Record, or 0 when it records none, and write it back there whenever it changes so a restart resumes the count — this story boundary's attempt counter. Every stall respawn or early-stop resume of the code-review, fix and QA sub-agents below, and every fix-and-re-run of Phase 4, counts toward it; past 2 retries the story goes to the `boundary_failed` anchor below (R8)</action>

      <anchor id="story_review" />
      <!-- Full gate, serially (R12): re-run on every return here, so a fix made at the boundary is proven against the whole suite, not only the tasks it touched -->
      <action>Run the project's full verification gate (full test, race and e2e suites) in the orchestrator: one heavy gate at a time, each tool call under about 9 minutes (a longer gate runs detached with an `EXIT=` line and is polled in slices — R8), with no heavy sub-agent check running beside it. If anything dies with `signal: killed` or exit 137, read the memory peak before recording a test failure — an OOM is re-run serially, not filed as a product defect.</action>

      <!-- Full story code review at boundary -->
      <action>Spawn code-review sub-agent, its prompt opening with {{execution_context}} (R7). It reads fully and follows the installed code-review workflow — every step of it, including the BLOCKING 13th Man step that gate depends on, not as a reference but as the steps to execute:
        `{project-root}/_skad/bmm/workflows/4-implementation/code-review/workflow.md`
        Scope: story {{story_key}} — full adversarial review of all changes since story began
        Earlier rounds: the story file's `Review Follow-ups (AI)` subsection and its `Review Round Log` hold what previous rounds filed. Read both before forming a finding, and file an invariant rather than a second instance of one already there.
        You are running unattended at a story boundary: answer no interactive question, and write NO story status, sprint-status entry or story-level tracker sync — I own the story's status here, and the adversarial QA gate still has to run after you. Your report ends with `OUTCOME: Approve | Changes Requested | Blocked`, and — on Approve or Changes Requested — the `ROUNDS:` line step 5 defines, in that order. A round blocked by its own 13th Man step ends at `OUTCOME: Blocked` and writes no ROUNDS line; that is correct.
      </action>
      <action>Monitor the code-review sub-agent with the stall detection of steps 4–6: a confirmed stall is TaskStop and a fresh spawn, an early stop is a resume of the same agent (R8). On each respawn or resume: Set {{boundary_retry_count}} = {{boundary_retry_count}} + 1, and once it exceeds 2 go to the `boundary_failed` anchor below instead of spawning or resuming again. Write the new value back to the story file's Dev Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
      <action>Read code-review output for outcome (Approve / Changes Requested / Blocked)</action>
      <check if="the report has no `OUTCOME:` line, or its value is not exactly one of Approve, Changes Requested, Blocked">
        <!-- Without this, an absent or misspelt line matches none of the checks below and falls through to QA — which is the Approve path. An unreadable verdict is not a pass. -->
        <output>🛑 Story {{story_key}}: the code review's report carries no usable `OUTCOME:` line, so its verdict cannot be read. dev-tasks does not guess a verdict.</output>
        <action>FIRST, write the local status: `development_status[{{story_key}}]` → `blocked` in sprint-status.yaml, and remove that entry's `current_task` comment. sprint-status.yaml is the file discovery reads, and step 1 looks for `in-progress` BEFORE anything else — a story left `in-progress` here is resumed by the next `goto step="1"` or by the next run, whatever the tracker says. Local first, then the tracker: if the run dies between the two, a story that is locally `blocked` and untouched in the tracker is caught by `op-status.py check` as drift, while the reverse is invisible to it and silently resumes.</action>
        <action>Ask that agent for the line, once, monitored with the stall detection of steps 4-6 like any other sub-agent exchange (R8) — an agent parked on this question must be declared stalled, not waited on. If it does not come back with exactly one of the three words, mark the story `blocked` (`python3 _skad/bmm/lib/op-status.py story {{story_key}} blocked --note "code review returned no readable verdict"`, R0), stop this story's sub-agents only, and `goto anchor="next_story"` — do NOT proceed to QA and do NOT mark anything. Report which agent and which story, and the number of blocked stories.
        If the SAME failure happens on the next story too, that is the tooling failing rather than the story, and it recurs whatever you pick up next: HALT then, and say that two consecutive stories produced no readable verdict.</action>
      </check>

      <check if="code-review outcome == 'Blocked'">
        <!-- Its own 13th Man step refuted the review or left a blocker open, and told it to stop without handing off. That round has no `ROUNDS:` line and no log entry by design; do not ask it for either, and do not resume a HALTed agent. -->
        <output>🛑 Story {{story_key}}: the story-level code review came back Blocked — its 13th Man step refused to close it. Nothing is marked complete.</output>
        <action>FIRST, write the local status: `development_status[{{story_key}}]` → `blocked` in sprint-status.yaml, and remove that entry's `current_task` comment. sprint-status.yaml is the file discovery reads, and step 1 looks for `in-progress` BEFORE anything else — a story left `in-progress` here is resumed by the next `goto step="1"` or by the next run, whatever the tracker says. Local first, then the tracker: if the run dies between the two, a story that is locally `blocked` and untouched in the tracker is caught by `op-status.py check` as drift, while the reverse is invisible to it and silently resumes.</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} blocked --note "<the code review's blockers, verbatim>"` (R0)</action>
        <action>BLOCK THE LANE, do not HALT the run: with the local status written first and the tracker mirrored, discovery skips this story (step 1 and the `next_story` search look only for `in-progress`, `ready-for-dev` and `backlog`), so it cannot be picked up again until a human unblocks it. Stop only THIS story's sub-agents, leave every other running pipeline alone, and `goto anchor="next_story"` to pick up independent work. A HALT here would end the whole run — R9 requires stopping every other pipeline first — and this failure is about this story's content, not about anything the next story depends on.</action>
        <action>Say in the run's output how many stories are now blocked and why, every time this fires. A blocked lane is only seen if something counts it; an uncounted one rots quietly, which is the failure mode a HALT does not have.</action>
        <goto anchor="next_story">This story is blocked and recorded; continue with work that does not depend on it.</goto>
      </check>
      <action>Read the report's final `ROUNDS:` line — `none`, `<n> new`, or `restatement-only`. A report that came back Approve or Changes Requested without one is incomplete: ask that agent for it, once, and do not guess it from the prose. If it still does not come back as exactly `none`, `<n> new` or `restatement-only`, block this story's lane as above and continue with independent work — do not proceed on an unreadable one, and do not end the run over one story. Anything other than those three strings fails the convergence check below by not matching it, so a garbled line would silently switch that check off for the rest of the story, and nothing would ever say so. Confirm the round wrote its entry to the story file's `Review Round Log`; write it yourself from the report if it did not, in the exact shape code-review step 5 defines (round number, scope, `ROUNDS:`, invariants filed, reviewer model) — the next round parses that shape to find the highest round number, and an entry in another shape breaks it.</action>
      <check if="this round and the one before it both report `ROUNDS: restatement-only` AND this round's OUTCOME is not Approve">
        <!-- Scoped to rounds that send work back: a round that APPROVES while restating a known invariant has cost one round and ends the loop anyway, so halting on it would block a story the review just passed. Its own terminal path on purpose: `boundary_failed` only halts once {{boundary_retry_count}} exceeds 2, and this condition can be true while the counter is still 1 or 2 — jumping there would fall straight through and mark the story `review`, which is the outcome this check exists to prevent. -->
        <output>🔁 Story {{story_key}}: two consecutive review rounds found only new instances of properties already filed. Another round buys the same finding again.
          The invariants already in the story's `Review Round Log` are what to fix; a human decides whether the story is done or the review needs a different question.
        </output>
        <action>FIRST, write the local status: `development_status[{{story_key}}]` → `blocked` in sprint-status.yaml, and remove that entry's `current_task` comment. sprint-status.yaml is the file discovery reads, and step 1 looks for `in-progress` BEFORE anything else — a story left `in-progress` here is resumed by the next `goto step="1"` or by the next run, whatever the tracker says. Local first, then the tracker: if the run dies between the two, a story that is locally `blocked` and untouched in the tracker is caught by `op-status.py check` as drift, while the reverse is invisible to it and silently resumes.</action>
        <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} blocked --note "review rounds converged on restatements; see the story's Review Round Log"` (R0)</action>
        <action>BLOCK THE LANE, do not HALT the run: with the local status written first and the tracker mirrored, discovery skips this story (step 1 and the `next_story` search look only for `in-progress`, `ready-for-dev` and `backlog`), so it cannot be picked up again until a human unblocks it. Stop only THIS story's sub-agents, leave every other running pipeline alone, and `goto anchor="next_story"` to pick up independent work. A HALT here would end the whole run — R9 requires stopping every other pipeline first — and this failure is about this story's content, not about anything the next story depends on.</action>
        <action>Say in the run's output how many stories are now blocked and why, every time this fires. A blocked lane is only seen if something counts it; an uncounted one rots quietly, which is the failure mode a HALT does not have.</action>
        <goto anchor="next_story">This story is blocked and recorded; continue with work that does not depend on it.</goto>
      </check>
      <!-- What this check does NOT cover, so nobody mistakes its silence for a clean loop: a second review round only happens when this loop re-enters `story_review`, which it does for High findings and for QA defects. A finding that stays Medium or Low never triggers another round, so repeated Medium/Low restatements never reach this check at all. They are caught at filing time instead — code-review step 4 merges an instance of an already-filed property into the invariant rather than filing it twice. -->

      <!-- Every outcome is routed. `Changes Requested` means the reviewer says the work should come back, and its Approve bar is "no HIGH or MEDIUM finding remains open" — so an open MEDIUM alone produces it. Routing only on High would drop that story straight through QA to a PR while the review that judged it said otherwise. -->
      <check if="code-review outcome == 'Changes Requested' with any HIGH or MEDIUM finding open">
        <action>Set {{open_high_count}} and {{open_medium_count}} from the report's own per-finding status, which code-review step 4 is required to give as `fixed` or `open` for every HIGH and MEDIUM finding. Count the `open` ones; never the discovery-time totals in its header, which were taken before any fix. A report that does not mark each finding one way or the other is incomplete — ask for it rather than estimating, the same way an unreadable OUTCOME is asked for above.</action>
        <output>🛑 Story-level code review left {{open_high_count}} High and {{open_medium_count}} Medium findings open. Resolving before marking story complete...</output>
        <action>Spawn fix sub-agent to address the open HIGH and MEDIUM findings (production code only), its prompt opening with {{execution_context}} (R7). A finding it cannot resolve in this round is reported as unresolved with the reason — never quietly left, because the next round reads the log and the retry budget is bounded.</action>
        <action>Monitor the fix sub-agent the same way. On each respawn or resume: Set {{boundary_retry_count}} = {{boundary_retry_count}} + 1, and once it exceeds 2 go to the `boundary_failed` anchor below. Write the new value back to the story file's Dev Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
        <action>After fixes: re-run test phase for affected tasks</action>
        <action>Set {{boundary_retry_count}} = {{boundary_retry_count}} + 1 — a fix-and-re-review of the story counts as a retry. Write the new value back to the story file's Dev Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
        <check if="{{boundary_retry_count}} > 2">
          <goto anchor="boundary_failed">Retries exhausted — the story code review did not come back clean</goto>
        </check>
        <goto anchor="story_review">Re-run the full gate and the code review over the fixed state: the code review carries its own 13th Man step, and what gets marked for review must be what was reviewed, not the version before the fix</goto>
      </check>

      <!-- Phase 4 — MANDATORY QA adversarial real-app verification + mock audit (rules R1/R4/R5) -->
      <!-- Reaching here means Approve: every other outcome was routed above, and an unreadable one halted. LOW findings do not hold a story — code-review files them as `Review Follow-ups (AI)` and still reports Approve, which is why Approve is the only verdict that arrives here. Nothing falls through unremarked. -->
      <anchor id="qa_run" />
      <output>🧪 **Phase 4: QA adversarial verification** — story {{story_key}}</output>
      <action tag="op-sync">Every defect QA finds is filed as a Bug under the story in the same run: `python3 _skad/bmm/lib/op-status.py bug {{story_key}} "<one line>" --body-file <repro>`; when one is fixed, close it: `python3 _skad/bmm/lib/op-status.py bug-close <bug-wp-id> --note "<the fix, and what re-verified it>"`. A finding recorded only in a QA markdown file is a finding the tracker cannot show anyone.</action>
      <action critical="true">Spawn the ADVERSARIAL QA agent (`bmm/agents/qa`, command [AV]), its prompt opening with {{execution_context}} (R7). QA MUST:
        1. MOCK AUDIT — inspect every test the story labels integration/E2E and FLAG any mock (in-memory fakes, in-process servers with stubbed downstreams, monkeypatched services/clients, fake databases). Any such mock is a DEFECT (rule R1).
        2. REAL-APP E2E — drive the REAL application (browser / agent-browser / Playwright / real HTTP) on REAL infrastructure and adversarially attempt to break the story's user journey end-to-end (do NOT merely re-run the dev's tests).
        3. INFRA GAP — if a real-infra check cannot run because infrastructure is missing, HALT and route the gap to an Infrastructure Epic (rule R2); do not accept a mock.
        4. TRACEABILITY — confirm the story traces to its epic/capability/GOAL and flag any orphan/unwired flow (rule R3).
      </action>
      <action>Monitor the QA sub-agent with the same stall detection. On each respawn or resume: Set {{boundary_retry_count}} = {{boundary_retry_count}} + 1, and once it exceeds 2 go to the `boundary_failed` anchor below. Then read its verdict (Pass / Defects-Found / Blocked-on-Infra). Write the new value back to the story file's Dev Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
      <check if="QA verdict != 'Pass'">
        <output>🛑 QA adversarial verification FAILED for {{story_key}} — {{qa_summary}}. Story is NOT complete.</output>
        <check if="QA verdict != 'Blocked-on-Infra'">
          <action>Set {{boundary_retry_count}} = {{boundary_retry_count}} + 1 — a fix-and-re-run of Phase 4 counts as a retry. Write the new value back to the story file's Dev Agent Record now, not at the next read — a count that stays in memory grants the next session a fresh budget.</action>
          <check if="{{boundary_retry_count}} > 2">
            <goto anchor="boundary_failed">Retries exhausted — no further fix or re-run</goto>
          </check>
        </check>
        <check if="QA verdict == 'Blocked-on-Infra'">
          <action>Record the gap against the Infrastructure Epic, set the story status to blocked, and HALT — do NOT mark complete.</action>
          <action>FIRST, write the local status: `development_status[{{story_key}}]` → `blocked` in sprint-status.yaml, and remove that entry's `current_task` comment. sprint-status.yaml is the file discovery reads, and step 1 looks for `in-progress` BEFORE anything else — a story left `in-progress` here is resumed by the next `goto step="1"` or by the next run, whatever the tracker says. Local first, then the tracker: if the run dies between the two, a story that is locally `blocked` and untouched in the tracker is caught by `op-status.py check` as drift, while the reverse is invisible to it and silently resumes.</action>
          <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} blocked --note "<the infra gap, and the Infrastructure Epic it was recorded against>"` (R0). A story that halted shows as blocked in the tracker, never as quietly in-progress — one of the three HALT paths that change the story's own status (see R0), and it is the one someone reading the tracker most needs to see.</action>
          <action>HALT</action>
        </check>
        <action>Do not proceed to mark the story complete until QA verdict == 'Pass'.</action>
        <check if="QA verdict == 'Defects-Found' (the infra HALT above has already stopped the run when it applied)">
          <action>If mocks were found in integration tests: spawn a fix sub-agent, its prompt opening with {{execution_context}} (R7), to re-point them at real infrastructure.</action>
          <action>For defects other than mocks: spawn a fix sub-agent scoped to the QA defects (production code only, never tests), its prompt opening with {{execution_context}} (R7).</action>
          <action>Re-run the Test phase for the affected tasks.</action>
          <goto anchor="story_review">Re-run the full gate, the code review and QA over the fixed state — the code review carries its own 13th Man step, so what gets marked for review is what was reviewed; the retry check above bounds this loop</goto>
        </check>
      </check>

      <!-- Boundary failure path: reached by goto once {{boundary_retry_count}} exceeds 2; on a Pass the check below is false and the flow continues -->
      <anchor id="boundary_failed" />
      <check if="{{boundary_retry_count}} > 2">
        <output>🚫 Story {{story_key}}: the story-boundary code review / fix / QA loop did not reach a Pass after 2 retries — {{qa_summary}}. The story is NOT complete and stays in-progress. Manual intervention required.</output>
        <action>HALT — do NOT mark the story complete</action>
      </check>

      <!-- `review` is INTERMEDIATE: it means a pull request is open, which proves nothing was
           verified. The story closes at `done`, after the deployed-or-running check below. -->
      <action>Update story file Status → "review"</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} review --note "<tasks passed, review outcome, QA verdict>"` then `python3 _skad/bmm/lib/op-status.py check {{story_key}}` — the boundary does not close while that check reports a disagreement (R0).</action>
      <action>Update sprint-status.yaml: development_status[{{story_key}}] → "review"</action>
      <action>Remove current_task comment from sprint-status entry</action>
      <action>Update last_updated to current date</action>

      <!-- OpenProject: sync story-complete status -->
      <check if="{{op_enabled}} == true">
        <action>Read COMPLETE {{op_sync_workflow}}</action>
        <action>Execute ACTION: story-complete with:
          - story_key = {{story_key}}
          - project_root = {project-root}
        </action>
        <critical>OP sync failure must NOT block the pipeline. Log warning and continue.</critical>
      </check>

      <!-- Pull request: the story is delivered through branch → PR → main -->
      <output>📬 **Opening pull request(s)** — story {{story_key}}</output>
      <critical>This block pushes branches and opens pull requests. It NEVER merges, tags or releases, in any autonomy mode — merging is governed only by R14 and *Merging Stacked PRs* below.</critical>
      <action>For every repo the story changed (each pipeline's {{work_repo_path}}, deduplicated — code repos and the repo holding the task files and sprint status alike): run `git -C <repo> branch --show-current`. If it prints `main` (or the repo's default branch), HALT — nothing is pushed to main. Commit the orchestration files the orchestrator owns (R7): task files, story file, sprint status, tracker maps, review and QA reports. Then `git -C <repo> status --short` must show no uncommitted change belonging to this story. A commit made after the full gate above that touches anything other than orchestration files means the gate is re-run before pushing.</action>
      <action>Push without force: `git -C <repo> push -u origin HEAD` — push HEAD, not a branch name, so the commit just checked is the commit pushed. Record `git -C <repo> rev-parse HEAD` as that repo's {{pr_head_sha}}.</action>
      <action>Look for an open PR for the branch first, from inside the repo: `gh pr list --head <branch> --state open --json number,url,baseRefName`. If one exists (a resumed run), adopt it and update its body; never open a second PR for the same branch. If the lookup itself fails, that is a failure of this block, not "no PR found".</action>
      <action>Otherwise open one, from inside the repo: `gh pr create --base main --head <branch> --title "<story_key>: <story title>" --body-file <body file>`. A branch stacked on another open PR's branch targets that branch instead, and is retargeted to `main` as *Merging Stacked PRs* describes. A story that changed several repos gets one PR per repo, each linking the others.</action>
      <action>The PR body names what produced every "green": for each gate, the exact command, where it ran (locally, or the named CI check), its exit code or summary line, and the SHA it ran against — plus the story code-review outcome and the Phase 4 QA verdict. A pull request with no checks is not a passing pull request: when no CI ran, the body says so in so many words, and the local gates named there are the only evidence. Never write "green", "passing" or "all checks pass" without naming the gate that produced it.</action>
      <action>Record each PR URL and {{pr_head_sha}} in the story file's Dev Agent Record, and set {{pr_summary}} = one line per PR (URL, head SHA, "open — not merged") for the boundary summary below.</action>
      <check if="a commit, push, PR lookup or PR creation failed">
        <output>🛑 Story {{story_key}} is in review but NOT delivered — stopped at: {{failed_pr_step}} ({{error}}). No pull request carries this story's work.</output>
        <action>HALT — never advance to the next story while this story's work is unpushed or has no PR</action>
      </check>

      <!-- ============ STORY ACCEPTANCE: DEPLOYED OR RUNNING ============
           A story's terminal state is `done`, and `review` — a pull request is open — is not
           evidence that anything was verified. Everything above this point was checked against
           a working tree; this checks the story's acceptance criteria against a system that is
           actually running. Until this passes, a hard dependency on this story is UNPROVEN
           (R19), which is what previously made story-level dependencies undecidable. -->
      <anchor id="story_acceptance" />
      <check if="the story file's Status is already `done`">
        <!-- Same guard the epic gate one level down already carries. A resumed run re-enters
             this boundary with every task `passed`, and without this it would spawn a second
             story-scope QA run against a story that has already been accepted — the cost of a
             full QA pass, for an answer already recorded. -->
        <action>Set {{story_final_status}} = "done" and skip this block: the story was accepted on an earlier run, and its environment and commit are recorded with its artifacts.</action>
        <goto anchor="story_summary">Already accepted; report and continue.</goto>
      </check>
      <action>Establish WHERE this story can be exercised: the environment the change is
        deployed to, or a running instance that contains it. Name the commit or image it is
        running, and confirm this story's work is in it — a green run against a system that
        does not contain the change is evidence for a claim it did not test. Reuse a running
        environment rather than provisioning one (R16).</action>
      <check if="no deployed or running system contains this story's work">
        <output>🛑 Story {{story_key}} cannot be accepted: no deployed or running system carries its work.
          It stays at `review` with its pull request open. `review` means a PR exists, not that anything was verified.
        </output>
        <action>Set {{story_final_status}} = "review (unverified — no environment)"</action>
        <action>Record what is missing — an unmerged PR, an undeployed image, an environment that does not exist — as the reason, so the next run knows what to fix rather than rediscovering it.</action>
        <goto anchor="story_summary">Report honestly and stop short of `done`</goto>
      </check>

      <action critical="true">Spawn the ADVERSARIAL QA agent (bmm/agents/qa, command [AV]) at STORY scope, its prompt opening with {{execution_context}} (R7). It verifies THIS story's acceptance criteria against that running system — driving the real application for a user-visible change, the real endpoint for an API — and it verifies the criteria as written, not the tests the implementer wrote for them.</action>
      <action>Monitor it with the stall detection of steps 4-6 (R8).</action>

      <check if="QA does not pass">
        <output>🛑 Story {{story_key}} failed acceptance against the running system: {{story_qa_summary}}</output>
        <action tag="op-sync">File each defect as a Bug under the story: `python3 _skad/bmm/lib/op-status.py bug {{story_key}} "<one line>" --body-file <evidence>` (R0), naming the criterion it fails.</action>
        <action>Set {{story_final_status}} = "review (acceptance failed)"</action>
        <action>BLOCK THE LANE, not the run (R18): this is one story's content. Write `development_status[{{story_key}}]` → `blocked` in sprint-status.yaml and clear its `current_task` comment, mirror it with `op-status.py story {{story_key}} blocked`, report the blocked count, and continue with independent work.</action>
        <goto anchor="next_story">Blocked on its own acceptance; pick up work that does not depend on it.</goto>
      </check>

      <action>Every acceptance criterion passed against a running system. Close the story:</action>
      <action>Update story file Status → `done`</action>
      <action>Update sprint-status.yaml: `development_status[{{story_key}}]` → `done`, and remove its `current_task` comment</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} done --note "<the criteria verified, the environment and commit they were verified against, and the QA evidence>"` (R0)</action>
      <action>Set {{story_final_status}} = "done"</action>
      <action>Record the environment and commit the acceptance ran against, with the story's artifacts — this is the evidence a later hard dependency on this story reads (R19), and a `done` with no such record is a status, not a verification.</action>
      <!-- ============ END STORY ACCEPTANCE ============ -->

      <anchor id="story_summary" />

      <check if="autonomy_mode == 'halt-after-story' OR autonomy_mode == 'halt-on-high'">
        <output>⏸️ **Story {{story_key}} complete — awaiting human approval**

          **Summary:**
          - Tasks completed: {{total_tasks}} / {{total_tasks}}
          - Story status: {{story_final_status}}
          - Code review: {{code_review_outcome}}
          - Pull request(s): {{pr_summary}}
          - Files changed: {{file_list_summary}}

          **Next story would be:** {{next_story_key}} (if applicable)

          Review the story, run manual tests if needed, then respond:
          - [A] Approve — continue to next story
          - [H] HALT — stop here

          Or provide specific feedback to address before continuing.
        </output>
        <ask>Approve and continue, or halt?</ask>

        <check if="user approves">
          <goto anchor="next_story" />
        </check>
        <check if="user halts or provides feedback">
          <action>Address feedback if provided, then re-ask for approval</action>
        </check>
      </check>

      <check if="autonomy_mode == 'full-hands-off'">
        <output>✅ Story {{story_key}} complete — PR(s) open, not merged: {{pr_summary}}. Advancing to next story...</output>
        <goto anchor="next_story" />
      </check>

      <anchor id="next_story" />
      <action>Load FULL sprint-status.yaml</action>
      <action>Find the next story after {{story_key}} (by order in file) where status is 'ready-for-dev' or 'backlog'</action>
      <action>Set {{current_epic}} = the epic of {{story_key}} (the epic prefix of its key: `1-6-loop-end-to-end` → `epic-1`), and {{next_story_epic}} = the epic of the story just found, or `none` when the search found nothing. A key that is not `<digits>-<digits>-<slug>` has no epic: set the value to `none`, which makes the comparison below false, and say so rather than guessing an epic from it — `op-status.py`'s own check skips such keys for the same reason.</action>
      <check if="{{next_story_epic}} != {{current_epic}}, AND sprint-status records no `{{current_epic}}-acceptance: done`">
        <!-- This is the ordinary case, not an edge case: sprint-planning writes EVERY epic's stories into sprint-status up front at `backlog`, so "the next story by order in file" is routinely the next EPIC's first story. Without this comparison the gate below would run only for the last epic in the project, and every other epic would be built on by the next one with its own criteria never read. -->
        <goto anchor="epic_acceptance">Epic {{current_epic}} has no actionable story left. Its gate runs BEFORE any story of the next epic starts — an epic is verified before anything is built on it, not after.</goto>
      </check>

      <check if="next story is 'backlog' (story file not yet created)">
        <output>📋 Next story {{next_story_key}} is in backlog. Auto-creating story file and task files...</output>
        <action>Read fully and follow: `{project-root}/_skad/bmm/workflows/4-implementation/create-story/workflow.md`</action>
        <note>create-story will generate the comprehensive story file from epics.md context and auto-chain into create-tasks to produce self-contained atomic task files. After completion, dev-tasks resumes with the new story.</note>
        <action>Set {{story_key}} = {{next_story_key}}</action>
        <goto step="1">Re-discover now that story and tasks exist</goto>
      </check>

      <check if="next story is 'ready-for-dev'">
        <action>Check if next story has Task Files (### Task Files in Dev Notes)</action>
        <check if="Task Files missing">
          <output>📋 Story {{next_story_key}} is ready-for-dev but has no task files. Auto-generating...</output>
          <action>Set {{story_path}} = path to {{next_story_key}} story file</action>
          <action>Read fully and follow: `{project-root}/_skad/bmm/workflows/4-implementation/create-tasks/workflow.md`</action>
          <note>create-tasks will atomize the story into self-contained task files with all context inlined for zero-context sub-agent execution.</note>
          <action>Set {{story_key}} = {{next_story_key}}</action>
          <goto step="1">Re-discover now that tasks exist</goto>
        </check>
        <action>Set {{story_key}} = {{next_story_key}}</action>
        <output>🚀 Starting next story: {{story_key}}</output>
        <goto step="1">Find position in new story</goto>
      </check>

          <!-- ============ EPIC ACCEPTANCE GATE ============
           Every story in this epic passed its own acceptance criteria and its own QA run. That is not
           the same claim as "the epic is done": a set of individually correct stories can still leave
           the epic's own acceptance criteria unmet, and nothing above this point has ever read them.
           R4/R5 says a story OR AN EPIC is not complete until the adversarial real-app gate passes;
           for stories that gate is Phase 4, and this is where it exists for an epic. It runs ONCE per
           epic, at its last story, so its cost is per epic rather than per story. -->
      <anchor id="epic_acceptance" />
      <action>Set {{boundary_epic}} = {{current_epic}} when a goto sent you here, or the epic of {{story_key}} when execution simply arrived — this block is a sibling of the checks above it, so it is reached BOTH ways.</action>
      <check if="sprint-status records `{{boundary_epic}}-acceptance: done`, or {{boundary_epic}} cannot be determined">
        <!-- Arrived by falling through after the gate had already passed, or with no epic to gate. Do nothing and let execution continue to the checks below — without this, the block re-runs its QA spawn and 13th Man review on every pass and the terminal "all epics complete" HALT below can never be reached. -->
        <action>Skip this block entirely.</action>
      </check>
      <check if="sprint-status records no `{{boundary_epic}}-acceptance: done` AND {{boundary_epic}} IS determined">
        <!-- The exact negation of the skip above, both clauses. With only the first, a story key that yields no epic makes the skip fire AND this run too, gating a `none` epic: the garbage row satisfies the epic-change check, and the real epic advances with its own gate never recorded. -->
        <action>Build the rollup, one row per epic acceptance criterion: which stories claim to satisfy it, and the artifact that proves each claim — a test name, a run log line, a screenshot, a fetched response. A criterion with no story under it is an ORPHAN; a criterion whose only evidence is a story's STATUS — `review`, which is this pipeline's terminal state for a passing story, or `done` where a human set it — is UNEVIDENCED. Both are failures of this gate, and both are the rollup the story-level gates structurally cannot see.</action>
        <action>Where the project defines a FEATURE level between story and epic, roll up to it first — story criteria discharge the feature's, the features' discharge the epic's — and carry the same orphan and unevidenced rules at each level. Where it does not, roll story criteria straight to the epic and say that is what you did.</action>

        <action critical="true">Spawn the ADVERSARIAL QA agent (bmm/agents/qa, command [AV]) at EPIC scope, its prompt opening with {{execution_context}} (R7). It drives the REAL application across the epic's user-visible surface on real infrastructure — a browser for a UI, the real endpoint for an API — and verifies the epic's acceptance criteria as a user meets them, not as the stories tested them one at a time. Story-level QA has already checked each story against itself; the only thing this run can add is what happens BETWEEN them, so tell it to work the seams: a flow that crosses stories, state one story leaves behind that another reads, a surface that regressed while a later story was built. Reuse the running environment (R16) — this gate is a verification, not a provisioning exercise — but first establish that the environment CONTAINS the whole epic. This workflow opens pull requests and stops by default (R14), so an epic's stories may sit in unmerged branches and no single environment holds them all. Name the commit the run drives and check every story of the epic is in it. If none is, that is this gate's blocking precondition: say which stories are unmerged and HALT — a green run against an environment missing half the epic is worse than no run, because it produces evidence for a claim it did not test.</action>
        <action>Monitor it with the stall detection of steps 4-6 (R8).</action>

        <check if="the QA run finds a defect, or the rollup has an orphan or unevidenced criterion">
        <output>🛑 Epic {{boundary_epic}} is NOT complete: {{epic_gate_summary}}. Its stories passed; the epic did not.</output>
        <action tag="op-sync">File each one as a Bug under the EPIC: `python3 _skad/bmm/lib/op-status.py bug {{boundary_epic}} "<one line>" --body-file <evidence>` (R0), naming which acceptance criterion it fails. Pass `{{boundary_epic}}` (`epic-N`), never `{{story_key}}` — `cmd_bug` resolves whatever key it is given straight to a work package, so the last story's key would file every cross-story defect under one arbitrary story, which is precisely the attribution this gate exists to correct.</action>
        <action>HALT — do NOT advance to the next epic. An epic that moves on with its own criteria unmet takes the gap into everything built on top of it, and the next epic's stories will be written against a foundation nobody verified.</action>
        </check>

        <action critical="true">13th Man review of THIS GATE, blocking, before the epic is called done: read fully and follow `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md` with stage_id="epic-acceptance". Give it the QUESTION — "determine whether epic {{boundary_epic}}'s acceptance criteria are met" — never the verdict, and point it at the evidence and the running application, never at this gate's own summary. The gate does not close on its own say-so; that is the whole reason it exists here rather than inside the QA run it is reviewing.</action>
        <action>Disposition every BLOCKER and every DISSENT before proceeding — fixed, scheduled with a named task, rejected with the reason, or accepted risk with an owner. An undispositioned finding is an open finding and the epic stays open.</action>
        <action>Record the rollup, the QA evidence and the review with the epic's other artifacts, and commit them in this unit of work — the evidence that an epic met its criteria is product knowledge, and it is the thing the next retrospective counts from.</action>
        <action>Record the passed gate where a LATER SESSION can see it: add the row `{{boundary_epic}}-acceptance: done` to sprint-status.yaml with a comment naming the review and the QA evidence. Use that key, NOT `{{boundary_epic}}: done` — the template documents the plain epic row as meaning "all stories in epic completed", which is the weaker thing this gate exists to distinguish itself from, and which a person may set by hand. `<epic>-retrospective` is the existing precedent for an add-on status with its own key, and mirror it: `python3 _skad/bmm/lib/op-status.py epic <N> done` — `<N>` is the BARE NUMBER (`1`, not `epic-1`); `cmd_epic` builds `epic-<N>` itself, so passing `epic-1` looks up `epic-epic-1` and fails. This is the opposite convention to the `bug` call above, which takes the full key. `python3 _skad/bmm/lib/op-status.py epic <N> done --note "<the rollup verdict and where its evidence lives>"` (R0). This record is what the epic-change check reads. Without it a resumed run — step 1 discovers a story with no epic scoping — would start the next epic having never run this gate, and nothing later looks back.</action>
        <goto anchor="next_story">Gate passed and recorded; pick up the next story, which may be in the next epic.</goto>
      </check>
      <!-- ============ END EPIC ACCEPTANCE GATE ============ -->

      <check if="no further stories are actionable in current epic">

        <action>Load sprint-status and check across ALL epics for next backlog story</action>
        <action>Find FIRST story across all epics where status = "backlog"</action>
        <check if="backlog story found in another epic">
          <output>🏁 **Current epic complete!** Moving to next epic...

            Epic progress summary:
            {{epic_summary}}

            Next story: {{next_backlog_story_key}} — auto-creating story and tasks...
          </output>
          <action>Read fully and follow: `{project-root}/_skad/bmm/workflows/4-implementation/create-story/workflow.md`</action>
          <note>create-story will auto-discover the next backlog story, generate the story file, and chain into create-tasks. After completion, dev-tasks resumes.</note>
          <goto step="1">Re-discover now that story and tasks exist</goto>
        </check>
        <action>Count the stories whose status is `blocked`, with the reason recorded for each. Lane-blocking (R18) means a blocked story is skipped by every search, so it cannot be found by "is anything actionable" — it has to be counted deliberately, and this is the only place left that can tell anyone.</action>
      <check if="no actionable stories remain anywhere AND one or more stories are `blocked`">
        <output>🟥 Implementation stopped with {{blocked_story_count}} blocked stor(y/ies), not complete:
          {{blocked_story_list}} — each with the reason it was blocked.
          Nothing else is actionable, so no further work will be attempted. These need a human.
        </output>
        <action>HALT — do NOT report the project as complete. A run that blocked lanes and then found nothing left has not finished; it has stopped, and saying "complete" here is the failure R18 trades immediacy away for.</action>
      </check>

      <check if="no actionable stories remain anywhere AND no story is `blocked`">
          <output>🏁 **All epics and stories are complete!**

            Epic progress summary:
            {{epic_summary}}

            No remaining backlog stories. The project implementation is complete.
          </output>
          <action>HALT</action>
        </check>
      </check>
    </check>

  </step>

</workflow>

---

## Task Status Reference

Task files use the `Status:` field to track pipeline phase. Valid values:

| Status            | Meaning                                                          |
| ----------------- | ---------------------------------------------------------------- |
| `ready-for-task`  | Task generated, not yet started                                  |
| `in-dev`          | Phase 1 (implement) sub-agent running                            |
| `in-dev-complete` | Implementation done, awaiting review phase                       |
| `in-review`       | Phase 2 (review) sub-agent running                               |
| `in-test`         | Phase 3 (test) sub-agent running                                 |
| `passed`          | All 3 phases complete — task is done                             |
| `failed`          | Halted due to unresolvable failure — requires human intervention |

**Routing.** Step 4 routes a task by the Status it finds, so a resumed run never re-implements finished work or erases a marker. Phases 2 and 3 HALT on any Status other than the one they expect, except that step 6 advances silently past `passed`. On a resumed run, Phases 2 and 3 re-attach to a recorded, still-running review or test agent instead of spawning a second one; a still-running full-hands-off fix or re-review agent HALTs the run. Rows marked *Default* are orchestrator defaults; the project owner may override them.

| Status step 4 finds | Route                                                                                                                                                                                        |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ready-for-task`    | Phase 1: Status → `in-dev`, spawn the implementation agent                                                                                                                                   |
| `in-dev`            | *Default:* re-attach to the recorded, still-running implementation agent (`implement_monitor`); otherwise HALT — interrupted mid-implementation, inspect the worktree, then reset the Status |
| `in-dev-complete`   | `implement_complete`: Status → `in-review`, then Phase 2                                                                                                                                     |
| `in-review`         | Phase 2 (step 5); HALT in `implement-only` mode                                                                                                                                              |
| `in-test`           | Phase 3 (step 6); HALT in `implement-only` mode                                                                                                                                              |
| `passed`            | Step 6, which advances to step 7 with no output                                                                                                                                              |
| `failed`            | *Default:* HALT — the task failed; reset its Status explicitly (e.g. to `ready-for-task`) before re-running. Never overwritten                                                               |
| anything else       | *Default:* HALT naming the value (a missing or empty Status included)                                                                                                                        |

---

## Stall Detection Reference

### Multi-Signal Activity Detection

The orchestrator polls sub-agent health every `effective_stall_warn` minutes using three independent signals:

| Signal                      | Command                                         | What it catches                                       |
| --------------------------- | ----------------------------------------------- | ----------------------------------------------------- |
| **TaskOutput growth**       | `TaskOutput(agent_id)` length delta             | Agent producing any output (tool calls, text, errors) |
| **Active child processes**  | `pgrep -la "curl\|python3\|node\|pytest\|jest"` | Agent running tools, test suites, API calls           |
| **Network socket activity** | `ss -tnp \| grep -c "ESTAB"`                    | Active TCP connections (MCP calls, HTTP APIs)         |

A stall is declared **only when ALL THREE signals are negative** for the full `effective_stall_kill` duration. Any single positive signal resets the stall timer.

### Stall Profile Thresholds

Each task file declares a `Stall Profile:` field that adjusts detection sensitivity:

| Profile      | `stall_warn` | `stall_kill` | When to use                                                                   |
| ------------ | ------------ | ------------ | ----------------------------------------------------------------------------- |
| `file-heavy` | 10 min       | 20 min       | Code writing, unit tests — frequent file writes expected                      |
| `api-heavy`  | 20 min       | 40 min       | MCP calls, API integrations, infra validation — long periods without file I/O |
| `mixed`      | 15 min       | 30 min       | Both file writes and API calls                                                |

Config overrides (`stall_warn_minutes`, `stall_kill_minutes`) always take precedence over profile defaults.

### Recovery Sequence

When a stall is confirmed (all signals negative for `stall_kill` duration):

1. `TaskStop(agent_id)` — kill stalled agent
2. `git -C <work repo path> status` — identify uncommitted partial changes in the task's own checkout or worktree (R13)
3. `git -C <work repo path> stash push -m "dev-tasks recovery: stalled on <task>"` — stash partial state
4. Spawn fresh sub-agent with Recovery Context describing the stash and last known point
5. Track retry count — HALT after 2 failed retries; an early-stop resume (below) counts as a retry too

**Early stop is not a stall.** If a sub-agent ended its turn before reaching a terminal status — waiting on a background job, or asking a question — resume that same agent with a message; do not kill it and do not spawn a duplicate (R8). Respawning with Recovery Context is only for a confirmed stall, after `TaskStop`. A resume is still an attempt: it counts toward the phase's retry limit ({{retry_count}} in Phase 1, {{review_retry_count}} in Phase 2, {{test_retry_count}} in Phase 3), and past that limit the task fails as a stalled one would.

### Why Not CPU/Memory?

**CPU** is unreliable as a stall signal: the sub-agent's process spends most of its time waiting on Anthropic's inference API (near-zero CPU) even while actively reasoning. CPU spikes only during tool execution — the same pattern as a sleeping process that wakes briefly. False negatives make it unsuitable as a primary signal.

**Memory** is not useful: agent RSS stays roughly constant once loaded. A stalled agent and an active agent are indistinguishable by memory footprint.

---

## Autonomy Mode Configuration

Set `autonomy_mode` in `{project-root}/_skad/bmm/config.yaml`:

```yaml
autonomy_mode: halt-after-story # implement-only | halt-after-story | halt-on-high | full-hands-off
stall_warn_minutes: 10
stall_kill_minutes: 20
```

Or override at invocation time: `dev-tasks autonomy_mode=full-hands-off`

---

## Merging Stacked PRs (only when the project owner has authorized it)

By default this workflow opens pull requests and stops: merging, tagging and releasing need the project owner's approval. **This section applies only when the project owner has given standing authorization to merge after testing.** Without that authorization, skip it and report the PRs as open.

When authorized, merge a stack base-first:

1. **Pin each merge to the reviewed head SHA** — the SHA the review and tests ran against (e.g. `gh pr merge <n> --match-head-commit <sha>`), so a commit pushed after review cannot land unreviewed.
2. **Retarget the next PR.** When merged branches are not auto-deleted, the next PR in the stack still targets the branch just merged; retarget its base to `main` before merging it.
3. **Resolve conflicts by merging `main` into the branch**, then re-run verification and pin the next merge to the new SHA. Never force-push a reviewed branch — it destroys the SHA the review was pinned to.
4. **Confirm the merged tree equals the verified tip.** After each merge, compare `git rev-parse <merge-commit>^{tree}` with `git rev-parse <verified-tip>^{tree}`. If they differ, something untested landed — typically `main` moved after verification. Stop, report it, and verify the merged result before merging anything stacked on it.

---

## Test Integrity Principle

> **Tests are the source of truth. They define what the code must do.**

If a verification command fails, the orchestrator and all sub-agents MUST:

- Diagnose the root cause in production code
- Fix production code only
- Re-run the command to confirm the fix

If fixing production code appears to require changing a test assertion, this is a signal that either:

1. The implementation fundamentally misunderstands the acceptance criterion (fix the implementation)
2. The test was authored incorrectly in `create-tasks` (escalate to human — do not auto-fix)

The orchestrator will HALT and surface a `TEST-INTEGRITY-HALT` when this situation is detected.
