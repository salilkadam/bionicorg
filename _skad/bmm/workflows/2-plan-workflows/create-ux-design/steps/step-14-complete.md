# Step 14: Workflow Completion

## MANDATORY EXECUTION RULES (READ FIRST):

- ✅ THIS IS A FINAL STEP - Workflow completion required

- 📖 CRITICAL: ALWAYS read the complete step file before taking any action - partial understanding leads to incomplete decisions
- 🔄 CRITICAL: When loading next step with 'C', ensure the entire file is read and understood before proceeding
- 🛑 NO content generation - this is a wrap-up step
- 📋 FINALIZE document and update workflow status
- 💬 FOCUS on completion, validation, and next steps
- 🎯 UPDATE workflow status files with completion information
- ✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the config `{communication_language}`

## EXECUTION PROTOCOLS:

- 🎯 Show your analysis before taking any action
- 💾 Update the main workflow status file with completion information
- 📖 Suggest potential next workflow steps for the user
- 🚫 DO NOT load additional steps after this one

## TERMINATION STEP PROTOCOLS:

- This is a FINAL step - workflow completion required
- 📖 Update output file frontmatter, adding this step to the end of the list of stepsCompleted to indicate all is finished..
- Output completion summary and next step guidance
- Update the main workflow status file with finalized document
- Suggest potential next workflow steps for the user
- Mark workflow as complete in status tracking

## CONTEXT BOUNDARIES:

- Complete UX design specification is available from all previous steps
- Workflow frontmatter shows all completed steps
- All collaborative content has been generated and saved
- Focus on completion, validation, and next steps

## YOUR TASK:

Complete the UX design workflow, update status files, and suggest next steps for the project.

## WORKFLOW COMPLETION SEQUENCE:

### 1. Announce Workflow Completion

Inform user that the UX design is complete:
"🎉 **UX Design Complete, {{user_name}}!**

I've successfully collaborated with you to create a comprehensive UX design specification for {{project_name}}.

**What we've accomplished:**

- ✅ Project understanding and user insights
- ✅ Core experience and emotional response definition
- ✅ UX pattern analysis and inspiration
- ✅ Design system choice and implementation strategy
- ✅ Core interaction definition and experience mechanics
- ✅ Visual design foundation (colors, typography, spacing)
- ✅ Design direction mockups and visual explorations
- ✅ User journey flows and interaction design
- ✅ Component strategy and custom component specifications
- ✅ UX consistency patterns for common interactions
- ✅ Responsive design and accessibility strategy

**The complete UX design specification is now available at:** `{planning_artifacts}/ux-design-specification.md`

**Supporting Visual Assets:**

- Color themes visualizer: `{planning_artifacts}/ux-color-themes.html`
- Design directions mockups: `{planning_artifacts}/ux-design-directions.html`

This specification is now ready to guide visual design, implementation, and development."

### 2. Workflow Status Update

Update the main workflow status file:

- Load `{status_file}` from workflow configuration (if exists)
- Update workflow_status["create-ux-design"] = "{default_output_file}"
- Save file, preserving all comments and structure
- Mark current timestamp as completion time

### 3. Suggest Next Steps

## 🕵️ MANDATORY GATE — 13th Man Review (ADVISORY)

**Run this BEFORE anything below.** This stage does not close on its own say-so.

Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md`

with `{{stage_id}}` = `ux-design`, `{{artifact_paths}}` = the artifact(s) this stage
produced, and `{{claim}}` = that the flows are complete and every rendered surface is accounted for.

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

Findings are advisory, but they are **recorded either way** — and a finding you reject is recorded with your reason, so the disagreement stays visible later.

Write the report to `{output_folder}/planning-artifacts/thirteenth-man/` yourself
from the block the review returns — the subagent may not have write access — and
**commit it**: it is product knowledge, not terminal output.

---

UX Design complete. Read fully and follow: `{project-root}/_skad/core/tasks/help.md`

### 5. Final Completion Confirmation

Congratulate the user on the completion you both completed together of the UX.



## SUCCESS METRICS:

✅ UX design specification contains all required sections
✅ All collaborative content properly saved to document
✅ Workflow status file updated with completion information
✅ Clear next step guidance provided to user
✅ Document quality validation completed
✅ User acknowledges completion and understands next options

## FAILURE MODES:

❌ Not updating workflow status file with completion information
❌ Missing clear next step guidance for user
❌ Not confirming document completeness with user
❌ Workflow not properly marked as complete in status tracking
❌ User unclear about what happens next

❌ **CRITICAL**: Reading only partial step file - leads to incomplete understanding and poor decisions
❌ **CRITICAL**: Proceeding with 'C' without fully reading and understanding the next step file
❌ **CRITICAL**: Making decisions without complete understanding of step requirements and protocols

## WORKFLOW COMPLETION CHECKLIST:

### Design Specification Complete:

- [ ] Executive summary and project understanding
- [ ] Core experience and emotional response definition
- [ ] UX pattern analysis and inspiration
- [ ] Design system choice and strategy
- [ ] Core interaction mechanics definition
- [ ] Visual design foundation (colors, typography, spacing)
- [ ] Design direction decisions and mockups
- [ ] User journey flows and interaction design
- [ ] Component strategy and specifications
- [ ] UX consistency patterns documentation
- [ ] Responsive design and accessibility strategy

### Process Complete:

- [ ] All steps completed with user confirmation
- [ ] All content saved to specification document
- [ ] Frontmatter properly updated with all steps
- [ ] Workflow status file updated with completion
- [ ] Next steps clearly communicated

## NEXT STEPS GUIDANCE:

**Immediate Options:**

1. **Wireframe Generation** - Create low-fidelity layouts based on UX spec
2. **Interactive Prototype** - Build clickable prototypes for testing
3. **Solution Architecture** - Technical design with UX context
4. **Figma Visual Design** - High-fidelity UI implementation
5. **Epic Creation** - Break down UX requirements for development

**Recommended Sequence:**
For design-focused teams: Wireframes → Prototypes → Figma Design → Development
For technical teams: Architecture → Epic Creation → Development

Consider team capacity, timeline, and whether user validation is needed before implementation.

## WORKFLOW FINALIZATION:

- Set `lastStep = 14` in document frontmatter
- Update workflow status file with completion timestamp
- Provide completion summary to user
- Do NOT load any additional steps

## FINAL REMINDER:

This UX design workflow is now complete. The specification serves as the foundation for all visual and development work. All design decisions, patterns, and requirements are documented to ensure consistent, accessible, and user-centered implementation.

**Congratulations on completing the UX Design Specification for {{project_name}}!** 🎉

**Core Deliverables:**

- ✅ UX Design Specification: `{planning_artifacts}/ux-design-specification.md`
- ✅ Color Themes Visualizer: `{planning_artifacts}/ux-color-themes.html`
- ✅ Design Directions: `{planning_artifacts}/ux-design-directions.html`

