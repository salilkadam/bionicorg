---
name: 'step-01-scope'
description: 'Load the stage profile and strip the conclusion out of the prompt before any review begins'

nextStepFile: '{project-root}/_skad/core/workflows/thirteenth-man-review/steps/step-02-derive.md'
stageProfiles: '{project-root}/_skad/core/workflows/thirteenth-man-review/stage-profiles.csv'
---

# Step 1: Scope and De-anchor

**Progress: Step 1 of 3** — Next: Independent Derivation

## MANDATORY EXECUTION RULES

- 🛑 **NEVER read the stage's conclusion into your working assumptions.** Read it once, to extract questions from it, then set it aside.
- 🚫 **FORBIDDEN** to begin derivation before the claim has been converted into neutral questions.
- 📖 Read the complete step file before acting.
- ✅ Speak in `{communication_language}`.

## WHY THIS STEP EXISTS

A review handed its conclusion is not a review. **Anchoring on a confident premise is
the specific failure this whole gate exists to prevent**, and it happens silently —
you will feel like you are checking, while actually you are looking for confirmation.

The de-anchoring is not a formality. It is the load-bearing part.

---

## YOUR TASK

### 1. Identify the stage

Resolve `{{stage_id}}` against `{stageProfiles}`.

- If `{{stage_id}}` was supplied, load that row.
- If not, ask which gate this is and match it. **Do not guess** — the profile decides
  what gets attacked, and the wrong profile reviews the wrong risk convincingly.
- If the stage is not in the profile list, ask whether a new profile should be added
  rather than improvising one. Record that as a finding.

Extract from the row: `artifacts`, `primary_sources`, `what_to_attack`, `blocking`.

### 2. Establish what is source and what is under test

Write the two lists explicitly before proceeding:

- **UNDER TEST** — the artifacts from the profile, plus anything in
  `{output_folder}/planning-artifacts/`. These are the project's own conclusions.
  **They are never evidence.**
- **SOURCE** — the `primary_sources` from the profile: code, config, chart values, CI
  workflows, schemas, vendor documentation, the running system.

If a file appears in both lists, it belongs in **UNDER TEST**.

### 3. Strip the answer — convert the claim into questions

Take `{{claim}}` and rewrite it as neutral questions. This is mechanical:

| Claimed as | Rewrite as |
|---|---|
| "The system does not rate-limit" | "What rate limiting exists? Is it wired? Is it on by default?" |
| "All 47 requirements are mapped" | "How many requirements are there? How many map to a story? Which do not?" |
| "Verify that X is safe" | "What are X's failure modes? What happens when each occurs?" |
| "We chose Postgres because it scales" | "What load must this carry? What does the evidence say each candidate sustains?" |

**Rules for the rewrite:**

- Every number in the claim becomes a question that **recomputes** it. Never carry a
  count forward — three counts were reported wrong on a real project because they were
  copied rather than computed.
- Every absence claim ("there is no…", "nothing does…") becomes the **three-question
  discipline**: does it exist / is it wired / is it on by default.
- Every "because" becomes "what evidence supports this, and what would contradict it".
- Drop all confidence language. "Clearly", "obviously", "as established" are removed.

### 4. Ask the disconfirming question first

For the central claim, write down: **what would the source show if this were false?**

Go looking for *that* first. This single reordering is what makes the difference
between finding things and confirming things.

### 5. Confirm model pinning

State which pinning level applied (see *MODEL PINNING* in the workflow):
subagent dispatch, explicit model switch, fresh context, or same-model degraded.

**Then run the comparison.** Record `DISPATCHER` (the model of the session
dispatching this review) and `MODEL` (the model the review actually runs as). If
they match, or either is unknown, this review is **`same-model (degraded)`** — say
so now, carry it into the report, and tell the user.

The reviewer cannot make this comparison; it cannot see the dispatcher's model from
inside. **The dispatching session is the only party that can, so it must.**

---

## OUTPUT OF THIS STEP

```
STAGE:        <stage_id> (blocking: yes|no)
MODEL:        <pinning level>
UNDER TEST:   <files — never used as evidence>
SOURCE:       <what will be used as evidence>
QUESTIONS:    <the de-anchored questions, numbered>
DISCONFIRMER: <what the source would show if the central claim were false>
```

## SUCCESS METRICS

✅ Stage matched to a real profile row, not improvised
✅ Every claim converted to a question; no conclusion carried forward
✅ Every count turned into a recomputation
✅ Absence claims expanded into the three-question discipline
✅ The disconfirming question written down BEFORE any derivation
✅ Model pinning level stated honestly

## FAILURE MODES

❌ Starting from the stage's conclusion and looking for support
❌ Accepting a number from the artifact instead of recomputing it
❌ Treating a planning artifact as evidence for another planning artifact
❌ Improvising a profile because the stage was not in the list
❌ Recording a same-model review as if it were independent

## NEXT STEP

Read fully and follow `{nextStepFile}`.
