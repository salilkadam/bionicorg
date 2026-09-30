# Task {{task_num}} of {{total_tasks}}: {{task_title}}

**Story:** [{{story_key}}](../../{{story_key}}.md)
**Status:** ready-for-task
**Stall Profile:** {{stall_profile}}
**Generated:** {{date}}

<!-- Status values (managed by dev-tasks orchestrator):
  ready-for-task  — generated, not yet started
  in-dev          — Phase 1 (implement) sub-agent running
  in-dev-complete — implementation done, awaiting review
  in-review       — Phase 2 (self-review) sub-agent running
  in-test         — Phase 3 (test) sub-agent running
  passed          — all 3 phases complete
  failed          — halted, requires human intervention
-->
<!-- Stall Profile values (controls stall detection sensitivity):
  file-heavy  — (default) task primarily writes/modifies files; standard thresholds
  api-heavy   — task makes MCP/API calls with long round-trips; extended thresholds
  mixed       — both file I/O and API calls; moderate thresholds
-->

---

## What This Task Does

{{task_description}}

Satisfies **Acceptance Criteria: {{ac_refs}}**

---

## Dependency Order

**Requires:** {{dependency_on}}

<!-- Task IDs within THIS story, e.g. "Tasks 1, 2a and 2b". dev-tasks expands ranges (R11). -->

**Depends on:** {{hard_dependencies}}

<!-- The story's own hard dependencies, repeated verbatim: one line per entry, `hard: <item key> — <what is needed>`, or `none` written out. Item keys across stories and epics, never task IDs — dev-tasks R19 refuses to start this task while a hard dependency's acceptance gate has not passed, and it reads THIS field. `Requires:` and `Depends on:` are read by different checks; do not merge them. -->

**Produces for next task:** {{produces_for_next}}

> If this is Task 1, there are no dependencies. Start here.

---

## Exact Files to Touch

| Action | File Path | What to do |
| ------ | --------- | ---------- |

{{files_table}}

**HARD LIMIT: 3 files maximum. If you discover you need to touch more files, HALT and ask the user.**

---

## Implementation Instructions

{{implementation_instructions}}

### Subtasks (complete in order)

{{subtasks_checklist}}

---

## Embedded Architecture Context

The following is the relevant excerpt from the project architecture document. This is the ONLY architecture context you need for this task. **Do not load the full architecture document.**

```
{{architecture_excerpt}}
```

---

## Embedded Code Patterns

The following patterns are already established in this codebase. Follow them exactly — do not invent new patterns.

{{code_patterns}}

### Existing File State (Current)

The following shows the current state of files you will modify. Use these as your baseline — do not assume file contents.

{{existing_file_excerpts}}

---

## Test Requirements

{{test_requirements}}

> **Rule R1:** if this task includes an integration/E2E test, it MUST hit the project's REAL infrastructure (name it) with an infra-precheck. **No mocks** in integration tests (in-memory fakes, in-process servers with stubbed downstreams, monkeypatched services). Unit tests may mock. **R2:** if the real infrastructure isn't wired, do NOT mock — mark blocked on the Infrastructure Epic.

### Verification Commands

Run these exact commands to verify this task is complete. **Run each line individually** — never paste the block into one `set -e` script. Every line must exit 0; a line starting with `!` passes only when its negated command fails. A scan for a leaked secret passes only on `grep` exit 1: exit 2 (file unreadable or missing) and an empty credential are failures, and a matching line is never printed.

**Every line must be able to FAIL, and each of these shapes cannot.** *(R22, added 2026-09-28. Story 2.2 shipped eighteen gates that could not report a failure — after fourteen adversarial review rounds ended clean, because no round read the gate lines as shell. `qa/logs/2-3/prototypes/vclint/` checks all of this mechanically; register it as a Verification Command of the story's evidence task.)*

- **Never end a line in a pager or filter.** `cmd 2>&1 | tail -20` reports **`tail`'s** exit status, so a failure exits 0. Write `out="$(cmd 2>&1)"; ec=$?; echo "$out" | tail -20; exit $ec`, or for a long run `cmd > "$LOG" 2>&1; ec=$?; tail -20 "$LOG"; exit $ec` — which also produces the evidence file. A pipeline whose **last** element is the assertion (`… | wc -l | grep -qx 1`) is sound.
- **Compare every count you produce.** `go test … | grep -c -- '--- PASS'` passes on **any non-zero count**, so a six-row table that shipped one row passes. Write `n=$(… | grep -cE -- '--- PASS: TestX(/| )') && test "$n" -eq N`, with **N measured, not guessed**. A count that is only *displayed* needs no assertion; one that is a gate does.
- **Know `grep -c`'s polarity.** It exits **1 on zero matches**, so it is a gate only when the wanted count is ≥ 1. When zero is what you want, use `! grep -q PATTERN file`. And `n=$(… | grep -c X) && test "$n" -eq 0` can **never** pass — the `&&` short-circuits; add `|| true` inside the capture.
- **Never let `|| true`, `2>/dev/null` or a trailing `; echo "…"` stand in for a success signal.** A trailing `; echo` makes the line's status **`echo`'s**. `|| true` is legitimate only inside a capture that is then asserted.
- **Anchor `-run`, or say why.** `-run 'TestX'` also runs `TestXFoo`; `go test -run '<nonexistent>'` prints `PASS` and **exits 0**. If an unanchored prefix is deliberate, a sibling gate must assert completeness.
- **At least one line must fail BEFORE the work is done, and it must fail because of THIS task.** A gate citing a test that already exists passes whether or not the task does anything — anchoring and asserting it does not fix that, because the defect is the **referent**, not the shape. If a pre-existing test is deliberately modified, a **planted defect** in the new code, shown to make that test fail, is the only thing that proves the modification.
- **Never hand-sum a bound** whose violation someone has to diagnose; recompute it from its parts and plant a part that breaks it.

```bash
{{verification_commands}}
```

---

## DO NOT

{{do_not_list}}

**Always applies:**

- Do NOT modify files not listed in "Exact Files to Touch"
- Do NOT install new dependencies without halting and asking the user
- Do NOT refactor code outside the scope of this task
- Do NOT mark this task complete if any verification command fails
- Do NOT implement anything beyond what this task describes

---

## Completion Checklist

Before marking this task done, verify ALL of the following:

- [ ] All subtasks above are checked
- [ ] All verification commands pass with exit 0
- [ ] Only the listed files were modified
- [ ] No new dependencies were added outside story specifications
- [ ] Implementation matches the task description exactly (no extra features)

---

## Task Agent Record

### Completion Notes

_(Fill in after implementation — summarize what was built and tested)_

### Files Modified

_(List actual files touched — should match "Exact Files to Touch" above)_

### Deviations from Plan

_(Document any necessary deviations and why — keep empty if you followed the plan exactly)_
