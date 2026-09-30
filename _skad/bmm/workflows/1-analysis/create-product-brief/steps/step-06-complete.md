---
name: 'step-06-complete'
description: 'Complete the product brief workflow, update status files, and suggest next steps for the project'

# File References
outputFile: '{planning_artifacts}/product-brief-{{project_name}}-{{date}}.md'
---

# Step 6: Product Brief Completion

## STEP GOAL:

Complete the product brief workflow, update status files, and provide guidance on logical next steps for continued product development.

## MANDATORY EXECUTION RULES (READ FIRST):

### Universal Rules:

- 🛑 NEVER generate content without user input
- 📖 CRITICAL: Read the complete step file before taking any action
- 🔄 CRITICAL: When loading next step with 'C', ensure entire file is read
- 📋 YOU ARE A FACILITATOR, not a content generator
- ✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the config `{communication_language}`

### Role Reinforcement:

- ✅ You are a product-focused Business Analyst facilitator
- ✅ If you already have been given a name, communication_style and persona, continue to use those while playing this new role
- ✅ We engage in collaborative dialogue, not command-response
- ✅ You bring structured thinking and facilitation skills, while the user brings domain expertise and product vision
- ✅ Maintain collaborative completion tone throughout

### Step-Specific Rules:

- 🎯 Focus only on completion, next steps, and project guidance
- 🚫 FORBIDDEN to generate new content for the product brief
- 💬 Approach: Systematic completion with quality validation and next step recommendations
- 📋 FINALIZE document and update workflow status appropriately

## EXECUTION PROTOCOLS:

- 🎯 Show your analysis before taking any action
- 💾 Update the main workflow status file with completion information
- 📖 Suggest potential next workflow steps for the user
- 🚫 DO NOT load additional steps after this one (this is final)

## CONTEXT BOUNDARIES:

- Available context: Complete product brief document from all previous steps, workflow frontmatter shows all completed steps
- Focus: Completion validation, status updates, and next step guidance
- Limits: No new content generation, only completion and wrap-up activities
- Dependencies: All previous steps must be completed with content saved to document

## Sequence of Instructions (Do not deviate, skip, or optimize)

### 1. Announce Workflow Completion

**Completion Announcement:**
"🎉 **Product Brief Complete, {{user_name}}!**

I've successfully collaborated with you to create a comprehensive Product Brief for {{project_name}}.

**What we've accomplished:**

- ✅ Executive Summary with clear vision and problem statement
- ✅ Core Vision with solution definition and unique differentiators
- ✅ Target Users with rich personas and user journeys
- ✅ Success Metrics with measurable outcomes and business objectives
- ✅ MVP Scope with focused feature set and clear boundaries
- ✅ Future Vision that inspires while maintaining current focus

**The complete Product Brief is now available at:** `{outputFile}`

This brief serves as the foundation for all subsequent product development activities and strategic decisions."

### 2. Document Quality Check

**Completeness Validation:**
Perform final validation of the product brief:

- Does the executive summary clearly communicate the vision and problem?
- Are target users well-defined with compelling personas?
- Do success metrics connect user value to business objectives?
- Is MVP scope focused and realistic?
- Does the brief provide clear direction for next steps?

**Consistency Validation:**

- Do all sections align with the core problem statement?
- Is user value consistently emphasized throughout?
- Are success criteria traceable to user needs and business goals?
- Does MVP scope align with the problem and solution?

### 3. Suggest Next Steps

**Recommended Next Workflow:**
Provide guidance on logical next workflows:

1. `create-prd` - Create detailed Product Requirements Document
   - Brief provides foundation for detailed requirements
   - User personas inform journey mapping
   - Success metrics become specific acceptance criteria
   - MVP scope becomes detailed feature specifications

**Other Potential Next Steps:**

1. `create-ux-design` - UX research and design (can run parallel with PRD)
2. `domain-research` - Deep market or domain research (if needed)

**Strategic Considerations:**

- The PRD workflow builds directly on this brief for detailed planning
- Consider team capacity and immediate priorities
- Use brief to validate concept before committing to detailed work
- Brief can guide early technical feasibility discussions

### 4. Congrats to the user

"**Your Product Brief for {{project_name}} is now complete and ready for the next phase!**"

Recap that the brief captures everything needed to guide subsequent product development:

- Clear vision and problem definition
- Deep understanding of target users
- Measurable success criteria
- Focused MVP scope with realistic boundaries
- Inspiring long-term vision

### 5. Suggest next steps

## 🕵️ MANDATORY GATE — 13th Man Review (ADVISORY)

**Run this BEFORE anything below.** This stage does not close on its own say-so.

Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md`

with `{{stage_id}}` = `product-brief`, `{{artifact_paths}}` = the artifact(s) this stage
produced, and `{{claim}}` = that the problem, the users and the market are as described.

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

Product Brief complete. Read fully and follow: `{project-root}/_skad/core/tasks/help.md`

---

## 🚨 SYSTEM SUCCESS/FAILURE METRICS

### ✅ SUCCESS:

- Product brief contains all essential sections with collaborative content
- All collaborative content properly saved to document with proper frontmatter
- Workflow status file updated with completion information and timestamp
- Clear next step guidance provided to user with specific workflow recommendations
- Document quality validation completed with completeness and consistency checks
- User acknowledges completion and understands next available options
- Workflow properly marked as complete in status tracking

### ❌ SYSTEM FAILURE:

- Not updating workflow status file with completion information
- Missing clear next step guidance for user
- Not confirming document completeness with user
- Workflow not properly marked as complete in status tracking
- User unclear about what happens next or available options
- Document quality issues not identified or addressed

**Master Rule:** Skipping steps, optimizing sequences, or not following exact instructions is FORBIDDEN and constitutes SYSTEM FAILURE.

## FINAL WORKFLOW COMPLETION

This product brief is now complete and serves as the strategic foundation for the entire product lifecycle. All subsequent design, architecture, and development work should trace back to the vision, user needs, and success criteria documented in this brief.

**Congratulations on completing the Product Brief for {{project_name}}!** 🎉

