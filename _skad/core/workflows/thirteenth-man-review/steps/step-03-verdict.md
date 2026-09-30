---
name: 'step-03-verdict'
description: 'Produce the verdict, the mandatory dissent, and the blockers; write the report and hand the gate decision back to the stage'

previousStepFile: '{project-root}/_skad/core/workflows/thirteenth-man-review/steps/step-02-derive.md'
stageProfiles: '{project-root}/_skad/core/workflows/thirteenth-man-review/stage-profiles.csv'
---

# Step 3: Verdict and Dissent

**Progress: Step 3 of 3** — Final

## MANDATORY EXECUTION RULES

- 🛑 **DISSENT IS MANDATORY**, including on a `confirmed` verdict.
- 🚫 **FORBIDDEN** to record a verdict more confident than the evidence gathered.
- 💾 The report is written to disk before the gate decision is reported.
- ✅ Speak in `{communication_language}`.

## YOUR TASK

### 1. Choose the verdict honestly

| Verdict | Means |
|---|---|
| `confirmed` | Independently re-derived from source and it holds |
| `partly-confirmed` | Holds in part; the scope, strength or conditions are wrong |
| `refuted` | Source contradicts the claim |
| `cannot-determine` | The evidence needed was not obtainable, or the claim is unfalsifiable as stated |

**`cannot-determine` is a respectable verdict. Agreement you cannot evidence is not.**
If the claim cannot be tested as written, say so *and say what would make it testable*
— that is the actionable output.

### 2. Write the dissent — mandatory

Even on `confirmed`, identify where the claim **overstates, understates, or
mis-scopes**. There is almost always something:

- **Overstates** — true in the case checked, asserted generally. *A verifier that
  handles one collision class does not "never report success when blind".*
- **Understates** — the finding is worse or broader than recorded.
- **Mis-scopes** — true of this component, framed as true of the system; or a residual
  left undocumented because the main case was fixed.

**"No dissent" is itself a finding and must be justified.** In practice it almost
always means the review did not go deep enough — say that rather than leaving it
blank.

### 3. Separate blockers from observations

A **BLOCKER** is a finding that must be resolved before the stage may close. Reserve
it for: the claim is false, a requirement is unmapped, a gate does not work, a
"done" is not actually done, a failure mode is silent.

Everything else is an observation, carried forward but not gating.

Check the profile's `blocking` column. On a **blocking** stage, any BLOCKER stops the
gate. On a non-blocking stage, findings are advisory — **but they are still recorded,
and a rejected finding is recorded with the reason.**

### 3a. Disposition every DISSENT and OBSERVATION — not just the blockers

**A blocker stops the stage; dissent changes the document.** Acting only on
blockers is the commonest way this gate gets quietly neutered: the stage reopens,
the blockers get fixed, the stage closes, and every non-blocking finding is lost
because nothing required anyone to answer it.

**Each dissent and observation gets one of four dispositions, recorded:**

| Disposition | Means |
|---|---|
| **Fixed** | The artifact changed. Say where. |
| **Scheduled** | Real, not now. **Name the task or phase it became** — "later" is not a disposition. |
| **Rejected** | Checked and disagreed. **Record the reason**, so the disagreement is visible to the next reader rather than re-litigated. |
| **Accepted risk** | True, not fixing. Needs an owner and a trigger that revisits it. |

**An undispositioned finding is an open finding.** If the list is long, that is
information about the artifact, not a reason to skip the exercise.

**Why this rule exists.** On a real review the blockers were closed in three
successive rounds while the dissent went unread — and the dissent contained the
finding that the stage had been marked complete *while its own gate was still
open*, plus four claims that were traced from source but written as though
observed. **None of those was a blocker. All of them were wrong.**

---

### 4. State what you could not check

Copy the running list from Step 02 verbatim. Do not summarise it away.

An unchecked area that goes unmentioned silently reads as a checked one, which is how
a gap survives a review that "passed".

### 5. Write the report

Write to `{output_folder}/planning-artifacts/thirteenth-man/{{stage_id}}-review-{{date}}.md`:

```markdown
# 13th Man Review — {{stage_id}}

- **Date:** {{date}}
- **Dispatcher:** <the model of the session that dispatched this review>
- **Model:** <the model this review actually ran as>
- **Independent:** yes | **NO — same-model (degraded)** | unverified
- **Artifacts under test:** <paths>
- **Revision reviewed:** <commit SHA or content hash>
- **Verdict:** <verdict>
- **Gate:** blocking | advisory
- **Decision:** stage may close | stage does NOT close

## Questions asked
<the de-anchored questions from Step 01>

## Evidence
<the Q/CMD/OUT/READ blocks>

## Derivation
<how this was reached without using the stage's own conclusion>

## Dissent
<mandatory — where the claim overstates, understates or mis-scopes>

## Blockers
<numbered; empty list stated explicitly as "none">

## What I could not check
<verbatim from Step 02; never empty without justification>
```

This file is **product knowledge — commit it.** A review that exists only in a
terminal scrollback cannot be audited, cannot be diffed, and will be re-litigated.

### 6. Report the gate decision

Return the OUTPUT CONTRACT block from `workflow.md` to the calling stage, and state
plainly:

- **`refuted` or any BLOCKER on a blocking stage** → *"This stage does not close."*
  Name the exact findings that must be resolved.
- **`cannot-determine`** → the stage does not close on that point. Either get the
  evidence, or record an explicit, owned, accepted risk. **Silently proceeding is not
  an option.**
- **Otherwise** → the stage may close, **if this round reviewed the current
  revision** — a fix made after it is unreviewed text and needs another round.
  **The dissent carries forward into the next stage's inputs** — it is not discarded
  because the gate passed.

### 7. Remind the stage owner of the limits of this gate

The 13th Man is **a second opinion, not an oracle.** It has been wrong, and it flags
its own unchecked claims. The stage owner **checks findings before acting on them**,
but **may not ignore them silently** — a rejected finding is recorded with its reason,
so the disagreement is visible later.

---

## SUCCESS METRICS

✅ Verdict no stronger than the evidence
✅ Dissent present and substantive, even on `confirmed`
✅ Blockers separated from observations
✅ "Could not check" carried through verbatim
✅ Report written to disk and flagged for commit
✅ Gate decision stated plainly, not implied

## FAILURE MODES

❌ `confirmed` with no dissent and no justification for its absence
❌ A verdict stronger than the evidence gathered
❌ Blockers softened into observations to let a stage close
❌ Dropping the "could not check" list because it looked untidy
❌ Reporting the verdict without writing the report
❌ Recording a degraded same-model review as an independent one
