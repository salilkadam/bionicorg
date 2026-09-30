# Step 8: Architecture Completion & Handoff

## MANDATORY EXECUTION RULES (READ FIRST):

- 🛑 NEVER generate content without user input

- 📖 CRITICAL: ALWAYS read the complete step file before taking any action - partial understanding leads to incomplete decisions
- ✅ ALWAYS treat this as collaborative completion between architectural peers
- 📋 YOU ARE A FACILITATOR, not a content generator
- 💬 FOCUS on successful workflow completion and implementation handoff
- 🎯 PROVIDE clear next steps for implementation phase
- ⚠️ ABSOLUTELY NO TIME ESTIMATES - AI development speed has fundamentally changed
- ✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the config `{communication_language}`

## EXECUTION PROTOCOLS:

- 🎯 Show your analysis before taking any action
- 🎯 Present completion summary and implementation guidance
- 📖 Update frontmatter with final workflow state
- 🚫 THIS IS THE FINAL STEP IN THIS WORKFLOW

## YOUR TASK:

Complete the architecture workflow, provide a comprehensive completion summary, and guide the user to the next phase of their project development.

## COMPLETION SEQUENCE:

### 1. Congratulate the User on Completion

Both you and the User completed something amazing here - give a summary of what you achieved together and really congratulate the user on a job well done.

### 2. Update the created document's frontmatter

```yaml
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
workflowType: 'architecture'
lastStep: 8
status: 'complete'
completedAt: '{{current_date}}'
```

### 3. Next Steps Guidance

## 🕵️ MANDATORY GATE — 13th Man Review (BLOCKING)

**Run this BEFORE anything below.** This stage does not close on its own say-so.

Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md`

with `{{stage_id}}` = `architecture`, `{{artifact_paths}}` = the artifact(s) this stage
produced, and `{{claim}}` = that the design holds under failure and matches what the code already does.

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

Architecture complete. Read fully and follow: `{project-root}/_skad/core/tasks/help.md`

Upon Completion of task output: offer to answer any questions about the Architecture Document.


## SUCCESS METRICS:

✅ Complete architecture document delivered with all sections
✅ All architectural decisions documented and validated
✅ Implementation patterns and consistency rules finalized
✅ Project structure complete with all files and directories
✅ User provided with clear next steps and implementation guidance
✅ Workflow status properly updated
✅ User collaboration maintained throughout completion process

## FAILURE MODES:

❌ Not providing clear implementation guidance
❌ Missing final validation of document completeness
❌ Not updating workflow status appropriately
❌ Failing to celebrate the successful completion
❌ Not providing specific next steps for the user
❌ Rushing completion without proper summary

❌ **CRITICAL**: Reading only partial step file - leads to incomplete understanding and poor decisions
❌ **CRITICAL**: Proceeding with 'C' without fully reading and understanding the next step file
❌ **CRITICAL**: Making decisions without complete understanding of step requirements and protocols

## WORKFLOW COMPLETE:

This is the final step of the Architecture workflow. The user now has a complete, validated architecture document ready for AI agent implementation.

The architecture will serve as the single source of truth for all technical decisions, ensuring consistent implementation across the entire project development lifecycle.

