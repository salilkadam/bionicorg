---
name: 'step-05-adversarial-review'
description: 'Construct diff and invoke adversarial review skill'

nextStepFile: './step-06-resolve-findings.md'
---

# Step 5: Adversarial Code Review

**Goal:** Construct diff of all changes, invoke adversarial review skill, present findings.

---

## AVAILABLE STATE

From previous steps:

- `{baseline_commit}` - Git HEAD at workflow start (CRITICAL for diff)
- `{execution_mode}` - "tech-spec" or "direct"
- `{tech_spec_path}` - Tech-spec file (if Mode A)

---

### 1. Construct Diff

Build complete diff of all changes since workflow started.

### If `{baseline_commit}` is a Git commit hash:

**Tracked File Changes:**

```bash
git diff {baseline_commit}
```

**New Untracked Files:**
Only include untracked files that YOU created during this workflow (steps 2-4).
Do not include pre-existing untracked files.
For each new file created, include its full content as a "new file" addition.

### If `{baseline_commit}` is "NO_GIT":

Use best-effort diff construction:

- List all files you modified during steps 2-4
- For each file, show the changes you made (before/after if you recall, or just current state)
- Include any new files you created with their full content
- Note: This is less precise than Git diff but still enables meaningful review

### Capture as {diff_output}

Merge all changes into `{diff_output}`.

**Note:** Do NOT `git add` anything - this is read-only inspection.

---

### 2. Invoke Adversarial Review

With `{diff_output}` constructed, dispatch the review to the **`thirteenth-man`
subagent** (`.claude/agents/thirteenth-man.md`), passing `{diff_output}` as the
content to review.

This is the `quick-dev` gate. Its review profile — what to attack in a quick-dev
diff — is the `stage_id="quick-dev"` row of
`{project-root}/_skad/core/workflows/thirteenth-man-review/stage-profiles.csv`.
Read that row and use it; for a fuller review, run the workflow itself
(`{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md`) with
`{{stage_id}}` = `quick-dev`.

**Prefer this over `skad-review-adversarial-general` run in-session.** Information
asymmetry — a separate process with no context but the diff — removes *shared
conversation*, but it does not remove *shared blind spots*: the same model reviewing
its own diff makes the same mistakes twice and agrees with itself both times. The
`thirteenth-man` subagent is pinned to a different model, which is the only thing
that removes those.

**The pin is absolute; the requirement is relative.** Record your OWN model as
`DISPATCHER`, take the model the review reports as `MODEL`, and compare them. If they
match, or either is unknown, stamp the findings `same-model (degraded)` and **say so**
— the subagent cannot see your model from inside, so you are the only one who can
make that comparison.

If the `thirteenth-man` subagent is unavailable, fall back to
`skad-review-adversarial-general` with information asymmetry and record the review as
degraded.

Pass `{diff_output}` as the content to review. The skill should return a list of findings.

---

### 3. Process Findings

Capture the findings from the skill output.
**If zero findings:** HALT - this is suspicious. Re-analyze or request user guidance.
Evaluate severity (Critical, High, Medium, Low) and validity (real, noise, undecided).
DO NOT exclude findings based on severity or validity unless explicitly asked to do so.
Order findings by severity.
Number the ordered findings (F1, F2, F3, etc.).
If TodoWrite or similar tool is available, turn each finding into a TODO, include ID, severity, validity, and description in the TODO; otherwise present findings as a table with columns: ID, Severity, Validity, Description

---

## NEXT STEP

With findings in hand, read fully and follow: `{project-root}/_skad/bmm/workflows/skad-quick-flow/quick-dev/steps/step-06-resolve-findings.md` for user to choose resolution approach.

---

## SUCCESS METRICS

- Diff constructed from baseline_commit
- New files included in diff
- Skill invoked with diff as input
- Findings received
- Findings processed into TODOs or table and presented to user

## FAILURE MODES

- Missing baseline_commit (can't construct accurate diff)
- Not including new untracked files in diff
- Invoking skill without providing diff input
- Accepting zero findings without questioning
- Presenting fewer findings than the review skill returned without explicit instruction to do so
