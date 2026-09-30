---
name: 'step-04-review'
description: 'Review and finalize the tech-spec'

wipFile: '{implementation_artifacts}/tech-spec-wip.md'

# Task References
thirteenthManReview: '{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md'
---

# Step 4: Review & Finalize

**Progress: Step 4 of 4** - Final Step

## RULES:

- MUST NOT skip steps.
- MUST NOT optimize sequence.
- MUST follow exact instructions.
- ✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the config `{communication_language}`

## CONTEXT:

- Requires `{wipFile}` from Step 3. 
- MUST present COMPLETE spec content. Iterate until user is satisfied.
- **Criteria**: The spec MUST meet the **READY FOR DEVELOPMENT** standard defined in `workflow.md`.

## SEQUENCE OF INSTRUCTIONS

### 1. Load and Present Complete Spec

**Read `{wipFile}` completely and extract `slug` from frontmatter for later use.**

**Present to user:**

"Here's your complete tech-spec. Please review:"

[Display the complete spec content - all sections]

"**Quick Summary:**

- {task_count} tasks to implement
- {ac_count} acceptance criteria to verify
- {files_count} files to modify"

**Present review menu:**

Display: "**Select:** [D] 13th Man Review [C] Continue [E] Edit [Q] Questions [A] Advanced Elicitation [P] Party Mode"

**HALT and wait for user selection.**

#### Menu Handling Logic:

- IF D: Read fully and follow: {thirteenthManReview} with this step's output as {{artifact_paths}}. Give it the QUESTION, never the answer — hand it what the step set out to establish, not what it concluded. Process the verdict, the mandatory dissent and any BLOCKERS. If the verdict is `refuted`, or any BLOCKER is raised on a blocking stage, do NOT continue: return to this step and address the findings, then redisplay the menu. Otherwise present the dissent to the user, ask whether to fold it in, then redisplay the menu
- IF C: Proceed to Section 3 (Finalize the Spec)
- IF E: Proceed to Section 2 (Handle Review Feedback), then return here and redisplay menu
- IF Q: Answer questions, then redisplay this menu
- IF A: Read fully and follow: `{advanced_elicitation}` with current spec content, process enhanced insights, ask user "Accept improvements? (y/n)", if yes update spec then redisplay menu, if no keep original then redisplay menu
- IF P: Read fully and follow: `{party_mode_exec}` with current spec content, process collaborative insights, ask user "Accept changes? (y/n)", if yes update spec then redisplay menu, if no keep original then redisplay menu
- IF Any other comments or queries: respond helpfully then redisplay menu

#### EXECUTION RULES:

- ALWAYS halt and wait for user input after presenting menu
- ONLY proceed to finalize when user selects 'C'
- After other menu items execution, return to this menu

### 2. Handle Review Feedback

a) **If user requests changes:**

- Make the requested edits to `{wipFile}`
- Re-present the affected sections
- Ask if there are more changes
- Loop until user is satisfied

b) **If the spec does NOT meet the "Ready for Development" standard:**

- Point out the missing/weak sections (e.g., non-actionable tasks, missing ACs).
- Propose specific improvements to reach the standard.
- Make the edits once the user agrees.

c) **If user has questions:**

- Answer questions about the spec
- Clarify any confusing sections
- Make clarifying edits if needed

### 3. Finalize the Spec

**When user confirms the spec is good AND it meets the "Ready for Development" standard:**

## 🕵️ MANDATORY GATE — 13th Man Review (BLOCKING)

**Run this BEFORE anything below.** This stage does not close on its own say-so.

Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md`

with `{{stage_id}}` = `quick-spec`, `{{artifact_paths}}` = the artifact(s) this stage
produced, and `{{claim}}` = that the spec is genuinely ready for development.

**Give it the question, never the answer** — hand over what this stage set out to
establish, not what it concluded. A gate handed the conclusion confirms it.

**Pin it to a different model — and PROVE it, do not assume it.** The pin in
`.claude/agents/thirteenth-man.md` is absolute (`model: <name>`), but the
requirement is *relative*: the reviewer must differ from **whatever model is
running this session right now**. Those come apart silently the moment this
session runs on the pinned model.

So, every time:

1. Record **your own** model in the report as `DISPATCHER`.
2. The review returns the model it ran as, in `MODEL`.
3. **Compare them.** Same, or either one unknown → the report is stamped
   `MODEL: same-model (degraded)` and **you tell the user the gate ran
   degraded**. Do not let a subagent assert independence it cannot verify — it
   cannot see your model from inside.

A degraded review recorded as a normal one is worse than no review: it retires
the concern without earning it.

| Result | What happens |
|---|---|
| `refuted` | Stage does not close. Fix, then re-run this gate. |
| Any BLOCKER | Stage does not close. Resolve each, then re-run. |
| `cannot-determine` | Do not close on that point. Get the evidence, or record an explicit, owned, accepted risk. |
| `confirmed` / `partly-confirmed`, no blockers | Proceed — **after dispositioning the dissent.** |

**Blockers are not the whole output.** Every DISSENT and OBSERVATION gets a
recorded disposition — fixed, scheduled (name the task), rejected (record why),
or accepted risk (name an owner and a trigger). **An undispositioned finding is
an open finding**; acting only on blockers is how this gate gets quietly
neutered.

**HALT. This stage does not close** while the verdict is `refuted` or any BLOCKER is open. Do not announce completion, do not hand off to the next workflow, do not write any status. Address the findings and re-run this gate.

Write the report to `{output_folder}/planning-artifacts/thirteenth-man/` yourself
from the block the review returns — the subagent may not have write access — and
**commit it**: it is product knowledge, not terminal output.

---

a) Update `{wipFile}` frontmatter:

   ```yaml
   ---
   # ... existing values ...
   status: 'ready-for-dev'
   stepsCompleted: [1, 2, 3, 4]
   ---
   ```

b) **Rename WIP file to final filename:**
   - Using the `slug` extracted in Section 1
   - Rename `{wipFile}` → `{implementation_artifacts}/tech-spec-{slug}.md`
   - Store this as `finalFile` for use in menus below

### 4. Present Final Menu

a) **Display completion message and menu:**

```
**Tech-Spec Complete!**

Saved to: {finalFile}

---

**Next Steps:**

[A] Advanced Elicitation - refine further
[R] Adversarial Review - critique of the spec (highly recommended)
[B] Begin Development - start implementing now (not recommended)
[D] Done - exit workflow
[P] Party Mode - get expert feedback before dev

---

Once you are fully satisfied with the spec (ideally after **Adversarial Review** and maybe a few rounds of **Advanced Elicitation**), it is recommended to run implementation in a FRESH CONTEXT for best results.

Copy this prompt to start dev:

\`\`\`
quick-dev {finalFile}
\`\`\`

This ensures the dev agent has clean context focused solely on implementation.
```

b) **HALT and wait for user selection.**

#### Menu Handling Logic:

- IF A: Read fully and follow: `{advanced_elicitation}` with current spec content, process enhanced insights, ask user "Accept improvements? (y/n)", if yes update spec then redisplay menu, if no keep original then redisplay menu
- IF B: Read the entire workflow file at `{quick_dev_workflow}` and follow the instructions with the final spec file (warn: fresh context is better)
- IF D: Exit workflow - display final confirmation and path to spec
- IF P: Read fully and follow: `{party_mode_exec}` with current spec content, process collaborative insights, ask user "Accept changes? (y/n)", if yes update spec then redisplay menu, if no keep original then redisplay menu
- IF R: Execute Adversarial Review (see below)
- IF Any other comments or queries: respond helpfully then redisplay menu

#### EXECUTION RULES:

- ALWAYS halt and wait for user input after presenting menu
- After A, P, or R execution, return to this menu

#### Adversarial Review [R] Process:

1. **Invoke Adversarial Review Skill**:
       > With `{finalFile}` constructed, invoke the `skad-review-adversarial-general` skill. If possible, use information asymmetry: invoke the skill in a separate subagent or process with read access to the project, but no context except the `{finalFile}`.
       > Pass `{finalFile}` as the content to review. The skill should return a list of findings.

    2. **Process Findings**:
       > Capture the findings from the skill output.
       > **If zero findings:** HALT - this is suspicious. Re-analyze or request user guidance.
       > Evaluate severity (Critical, High, Medium, Low) and validity (real, noise, undecided).
       > DO NOT exclude findings based on severity or validity unless explicitly asked to do so.
       > Order findings by severity.
       > Number the ordered findings (F1, F2, F3, etc.).
       > If TodoWrite or similar tool is available, turn each finding into a TODO, include ID, severity, validity, and description in the TODO; otherwise present findings as a table with columns: ID, Severity, Validity, Description

    3. Return here and redisplay menu.

### 5. Exit Workflow

**When user selects [D]:**

"**All done!** Your tech-spec is ready at:

`{finalFile}`

When you're ready to implement, run:

```
quick-dev {finalFile}
```

Ship it!"

---

## REQUIRED OUTPUTS:

- MUST update status to 'ready-for-dev'.
- MUST rename file to `tech-spec-{slug}.md`.
- MUST provide clear next-step guidance and recommend fresh context for dev.

## VERIFICATION CHECKLIST:

- [ ] Complete spec presented for review.
- [ ] Requested changes implemented.
- [ ] Spec verified against **READY FOR DEVELOPMENT** standard.
- [ ] `stepsCompleted: [1, 2, 3, 4]` set and file renamed.
