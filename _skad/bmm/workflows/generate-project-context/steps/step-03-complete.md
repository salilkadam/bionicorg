# Step 3: Context Completion & Finalization

## MANDATORY EXECUTION RULES (READ FIRST):

- 🛑 NEVER generate content without user input
- ✅ ALWAYS treat this as collaborative completion between technical peers
- 📋 YOU ARE A FACILITATOR, not a content generator
- 💬 FOCUS on finalizing a lean, LLM-optimized project context
- 🎯 ENSURE all critical rules are captured and actionable
- ⚠️ ABSOLUTELY NO TIME ESTIMATES - AI development speed has fundamentally changed
- ✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the config `{communication_language}`

## EXECUTION PROTOCOLS:

- 🎯 Show your analysis before taking any action
- 📝 Review and optimize content for LLM context efficiency
- 📖 Update frontmatter with completion status
- 🚫 NO MORE STEPS - this is the final step

## CONTEXT BOUNDARIES:

- All rule categories from step-2 are complete
- Technology stack and versions are documented
- Focus on final review, optimization, and completion
- Ensure the context file is ready for AI agent consumption

## YOUR TASK:

Complete the project context file, optimize it for LLM efficiency, and provide guidance for usage and maintenance.

## COMPLETION SEQUENCE:

### 1. Review Complete Context File

Read the entire project context file and analyze:

**Content Analysis:**

- Total length and readability for LLMs
- Clarity and specificity of rules
- Coverage of all critical areas
- Actionability of each rule

**Structure Analysis:**

- Logical organization of sections
- Consistency of formatting
- Absence of redundant or obvious information
- Optimization for quick scanning

### 2. Optimize for LLM Context

Ensure the file is lean and efficient:

**Content Optimization:**

- Remove any redundant rules or obvious information
- Combine related rules into concise bullet points
- Use specific, actionable language
- Ensure each rule provides unique value

**Formatting Optimization:**

- Use consistent markdown formatting
- Implement clear section hierarchy
- Ensure scannability with strategic use of bolding
- Maintain readability while maximizing information density

### 3. Final Content Structure

Ensure the final structure follows this optimized format:

```markdown
# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

{{concise_technology_list}}

## Critical Implementation Rules

### Language-Specific Rules

{{specific_language_rules}}

### Framework-Specific Rules

{{framework_patterns}}

### Testing Rules

{{testing_requirements}}

### Code Quality & Style Rules

{{style_and_quality_patterns}}

### Development Workflow Rules

{{workflow_patterns}}

### Critical Don't-Miss Rules

{{anti_patterns_and_edge_cases}}

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

Last Updated: {{date}}
```

### 4. Present Completion Summary

Based on user skill level, present the completion:

**Expert Mode:**
"Project context complete. Optimized for LLM consumption with {{rule_count}} critical rules across {{section_count}} sections.

File saved to: `{output_folder}/project-context.md`

Ready for AI agent integration."

**Intermediate Mode:**
"Your project context is complete and optimized for AI agents!

**What we created:**

- {{rule_count}} critical implementation rules
- Technology stack with exact versions
- Framework-specific patterns and conventions
- Testing and quality guidelines
- Workflow and anti-pattern rules

**Key benefits:**

- AI agents will implement consistently with your standards
- Reduced context switching and implementation errors
- Clear guidance for unobvious project requirements

**Next steps:**

- AI agents should read this file before implementing
- Update as your project evolves
- Review periodically for optimization"

**Beginner Mode:**
"Excellent! Your project context guide is ready! 🎉

**What this does:**
Think of this as a 'rules of the road' guide for AI agents working on your project. It ensures they all follow the same patterns and avoid common mistakes.

**What's included:**

- Exact technology versions to use
- Critical coding rules they might miss
- Testing and quality standards
- Workflow patterns to follow

**How AI agents use it:**
They read this file before writing any code, ensuring everything they create follows your project's standards perfectly.

Your project context is saved and ready to help agents implement consistently!"

### 5. Final File Updates

Update the project context file with completion information:

**Frontmatter Update:**

```yaml
---
project_name: '{{project_name}}'
user_name: '{{user_name}}'
date: '{{date}}'
sections_completed:
  ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'quality_rules', 'workflow_rules', 'anti_patterns']
status: 'complete'
rule_count: { { total_rules } }
optimized_for_llm: true
---
```

**Add Usage Section:**
Append the usage guidelines from step 3 to complete the document.

### 6. Completion Validation

Final checks before completion:

**Content Validation:**
✅ All critical technology versions documented
✅ Language-specific rules are specific and actionable
✅ Framework rules cover project conventions
✅ Testing rules ensure consistency
✅ Code quality rules maintain standards
✅ Workflow rules prevent conflicts
✅ Anti-pattern rules prevent common mistakes

**Format Validation:**
✅ Content is lean and optimized for LLMs
✅ Structure is logical and scannable
✅ No redundant or obvious information
✅ Consistent formatting throughout

### 7. Completion Message

Present final completion to user:

"✅ **Project Context Generation Complete!**

Your optimized project context file is ready at:
`{output_folder}/project-context.md`

**📊 Context Summary:**

- {{rule_count}} critical rules for AI agents
- {{section_count}} comprehensive sections
- Optimized for LLM context efficiency
- Ready for immediate agent integration

**🎯 Key Benefits:**

- Consistent implementation across all AI agents
- Reduced common mistakes and edge cases
- Clear guidance for project-specific patterns
- Minimal LLM context usage

**📋 Next Steps:**

1. AI agents will automatically read this file when implementing
2. Update this file when your technology stack or patterns evolve
3. Review quarterly to optimize and remove outdated rules

Your project context will help ensure high-quality, consistent implementation across all development work. Great work capturing your project's critical implementation requirements!"

## SUCCESS METRICS:

✅ Complete project context file with all critical rules
✅ Content optimized for LLM context efficiency
✅ All technology versions and patterns documented
✅ File structure is logical and scannable
✅ Usage guidelines included for agents and humans
✅ Frontmatter properly updated with completion status
✅ User provided with clear next steps and benefits

## FAILURE MODES:

❌ Final content is too verbose for LLM consumption
❌ Missing critical implementation rules or patterns
❌ Not optimizing content for agent readability
❌ Not providing clear usage guidelines
❌ Frontmatter not properly updated
❌ Not validating file completion before ending

## 🕵️ MANDATORY GATE — 13th Man Review (BLOCKING)

**Run this BEFORE anything below.** This stage does not close on its own say-so.

Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md`

with `{{stage_id}}` = `project-context`, `{{artifact_paths}}` = the artifact(s) this stage
produced, and `{{claim}}` = that the generated context matches what the repository actually contains.

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

## WORKFLOW COMPLETE:

This is the final step of the Generate Project Context workflow. The user now has a comprehensive, optimized project context file that will ensure consistent, high-quality implementation across all AI agents working on the project.

The project context file serves as the critical "rules of the road" that agents need to implement code consistently with the project's standards and patterns.
