---
name: sprint-planning
description: 'Generate sprint status tracking from epics. Use when the user says "run sprint planning" or "generate sprint plan"'
---

# Sprint Planning Workflow

**Goal:** Generate sprint status tracking from epics, detecting current story statuses and building a complete sprint-status.yaml file.

**Your Role:** You are a Scrum Master generating and maintaining sprint tracking. Parse epic files, detect story statuses, and produce a structured sprint-status.yaml.

---

## INITIALIZATION

### Configuration Loading

Load config from `{project-root}/_skad/bmm/config.yaml` and resolve:

- `project_name`, `user_name`
- `communication_language`, `document_output_language`
- `implementation_artifacts`
- `planning_artifacts`
- `date` as system-generated current datetime
- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`

### Paths

- `installed_path` = `{project-root}/_skad/bmm/workflows/4-implementation/sprint-planning`
- `template` = `{installed_path}/sprint-status-template.yaml`
- `checklist` = `{installed_path}/checklist.md`
- `tracking_system` = `file-system`
- `project_key` = `NOKEY`
- `story_location` = `{implementation_artifacts}`
- `story_location_absolute` = `{implementation_artifacts}`
- `epics_location` = `{planning_artifacts}`
- `epics_pattern` = `*epic*.md`
- `status_file` = `{implementation_artifacts}/sprint-status.yaml`

### Input Files

| Input | Path | Load Strategy |
|-------|------|---------------|
| Epics | `{planning_artifacts}/*epic*.md` (whole) or `{planning_artifacts}/*epic*/*.md` (sharded) | FULL_LOAD |

### Context

- `project_context` = `**/project-context.md` (load if exists)

---

## EXECUTION

### Document Discovery - Full Epic Loading

**Strategy**: Sprint planning needs ALL epics and stories to build complete status tracking.

**Epic Discovery Process:**

1. **Search for whole document first** - Look for `epics.md`, `bmm-epics.md`, or any `*epic*.md` file
2. **Check for sharded version** - If whole document not found, look for `epics/index.md`
3. **If sharded version found**:
   - Read `index.md` to understand the document structure
   - Read ALL epic section files listed in the index (e.g., `epic-1.md`, `epic-2.md`, etc.)
   - Process all epics and their stories from the combined content
   - This ensures complete sprint status coverage
4. **Priority**: If both whole and sharded versions exist, use the whole document

**Fuzzy matching**: Be flexible with document names - users may use variations like `epics.md`, `bmm-epics.md`, `user-stories.md`, etc.

<workflow>

<step n="1" goal="Parse epic files and extract all work items">
<action>Load {project_context} for project-wide patterns and conventions (if exists)</action>
<action>Communicate in {communication_language} with {user_name}</action>
<action>Look for all files matching `{epics_pattern}` in {epics_location}</action>
<action>Could be a single `epics.md` file or multiple `epic-1.md`, `epic-2.md` files</action>

<action>For each epic file found, extract:</action>

- Epic numbers from headers like `## Epic 1:` or `## Epic 2:`
- Story IDs and titles from patterns like `### Story 1.1: User Authentication`
- Convert story format from `Epic.Story: Title` to kebab-case key: `epic-story-title`

**Story ID Conversion Rules:**

- Original: `### Story 1.1: User Authentication`
- Replace period with dash: `1-1`
- Convert title to kebab-case: `user-authentication`
- Final key: `1-1-user-authentication`

<action>Build complete inventory of all epics and stories from all epic files</action>
</step>

<step n="2" goal="Build sprint status structure">
<action>For each epic found, create entries in this order:</action>

1. **Epic entry** - Key: `epic-{num}`, Default status: `backlog`
2. **Story entries** - Key: `{epic}-{story}-{title}`, Default status: `backlog`
3. **Retrospective entry** - Key: `epic-{num}-retrospective`, Default status: `optional`

**Example structure:**

```yaml
development_status:
  epic-1: backlog
  1-1-user-authentication: backlog
  1-2-account-management: backlog
  epic-1-retrospective: optional
```

</step>

<step n="3" goal="Apply intelligent status detection">
<action>For each story, detect current status by checking files:</action>

**Story file detection:**

- Check: `{story_location_absolute}/{story-key}.md` (e.g., `stories/1-1-user-authentication.md`)
- If exists → upgrade status to at least `ready-for-dev`

**Preservation rule:**

- If existing `{status_file}` exists and has more advanced status, preserve it
- Never downgrade status (e.g., don't change `done` to `ready-for-dev`)

**Status Flow Reference:**

- Epic: `backlog` → `in-progress` → `done`
- Story: `backlog` → `ready-for-dev` → `in-progress` → `review` → `done`
- Retrospective: `optional` ↔ `done`
  </step>

<step n="4" goal="Generate sprint status file">
<action>Create or update {status_file} with:</action>

**File Structure:**

```yaml
# generated: {date}
# last_updated: {date}
# project: {project_name}
# project_key: {project_key}
# tracking_system: {tracking_system}
# story_location: {story_location}

# STATUS DEFINITIONS:
# ==================
# Epic Status:
#   - backlog: Epic not yet started
#   - in-progress: Epic actively being worked on
#   - done: All stories in epic completed
#
# Epic Status Transitions:
#   - backlog → in-progress: Automatically when first story is created (via create-story)
#   - in-progress → done: Manually when all stories reach 'done' status
#
# Story Status:
#   - backlog: Story only exists in epic file
#   - ready-for-dev: Story file created in stories folder
#   - in-progress: Developer actively working on implementation
#   - review: Ready for code review (via Dev's code-review workflow)
#   - done: Story completed
#
# Retrospective Status:
#   - optional: Can be completed but not required
#   - done: Retrospective has been completed
#
# WORKFLOW NOTES:
# ===============
# - Epic transitions to 'in-progress' automatically when first story is created
# - Stories can be worked in parallel if team capacity allows
# - SM typically creates next story after previous one is 'done' to incorporate learnings
# - Dev moves story to 'review', then runs code-review (fresh context, different LLM recommended)

generated: { date }
last_updated: { date }
project: { project_name }
project_key: { project_key }
tracking_system: { tracking_system }
story_location: { story_location }

development_status:
  # All epics, stories, and retrospectives in order
```

<action>Write the complete sprint status YAML to {status_file}</action>
<action>CRITICAL: Metadata appears TWICE - once as comments (#) for documentation, once as YAML key:value fields for parsing</action>
<action>Ensure all items are ordered: epic, its stories, its retrospective, next epic...</action>
</step>

<step n="13m" goal="13th Man adversarial review (ADVISORY) — runs BEFORE this stage closes">
<critical>This stage does not close on its own say-so. Run this review FIRST; everything below is conditional on its result.</critical>
<action>Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md` with stage_id="sprint-plan", artifact_paths=the artifacts this stage produced, and claim=that the sprint status reflects the real state of every epic and story</action>
<critical>Give it the QUESTION, never the answer — hand over what this stage set out to establish, not what it concluded. A gate handed the conclusion confirms it.</critical>
<action>Record YOUR OWN model as DISPATCHER in the report. The pin in .claude/agents/thirteenth-man.md is absolute, but the requirement is RELATIVE — the reviewer must differ from whatever model is running THIS session right now. These come apart silently when this session runs on the pinned model.</action>
<action>Compare DISPATCHER against the MODEL the review reports it ran as. The subagent cannot see your model from inside, so YOU are the only one who can make this comparison.</action>
<check if="DISPATCHER == MODEL, or either is unknown">Stamp the report MODEL: same-model (degraded) and TELL THE USER the gate ran degraded. Never let a subagent assert independence it cannot verify — a degraded review recorded as a normal one retires the concern without earning it.</check>
<check if="verdict is refuted OR any BLOCKER is open">Record the findings in this stage's output before continuing.</check>
<check if="verdict is cannot-determine">Do not close on that point — obtain the evidence, or record an explicit, owned, accepted risk before continuing.</check>
<check if="verdict is confirmed or partly-confirmed with no blockers">Proceed ONLY after dispositioning every DISSENT and OBSERVATION, not just the blockers. Each gets one of: fixed (say where), scheduled (name the task or phase), rejected (record the reason), or accepted risk (name an owner and a trigger). An undispositioned finding is an open finding — acting only on blockers is how this gate gets quietly neutered.</check>
<action>Write the returned report to `{output_folder}/planning-artifacts/thirteenth-man/` YOURSELF (the subagent may lack write access) and commit it — it is product knowledge.</action>
</step>

<step n="5" goal="Validate and report">
<action>Perform validation checks:</action>

- [ ] Every epic in epic files appears in {status_file}
- [ ] Every story in epic files appears in {status_file}
- [ ] Every epic has a corresponding retrospective entry
- [ ] No items in {status_file} that don't exist in epic files
- [ ] All status values are legal (match state machine definitions)
- [ ] File is valid YAML syntax

<action>Count totals:</action>

- Total epics: {{epic_count}}
- Total stories: {{story_count}}
- Epics in-progress: {{in_progress_count}}
- Stories done: {{done_count}}

<action>Display completion summary to {user_name} in {communication_language}:</action>

**Sprint Status Generated Successfully**

- **File Location:** {status_file}
- **Total Epics:** {{epic_count}}
- **Total Stories:** {{story_count}}
- **Epics In Progress:** {{in_progress_count}}
- **Stories Completed:** {{done_count}}

**Next Steps:**

1. Review the generated {status_file}
2. Proceeding to create the first story file...

</step>

<step n="6" goal="Auto-chain: Create first story from backlog">
<critical>QUALITY GATE: Before chaining into create-story, verify sprint-status.yaml is valid and complete. The downstream create-story workflow depends on accurate sprint status data to discover the correct story and extract the right epic context.</critical>

<action>Load the FULL file: {status_file}</action>
<action>Parse the development_status section completely</action>

<!-- Pre-chain quality check -->
<action>Verify sprint-status.yaml quality before proceeding:
  - All epics from epics.md are present in development_status
  - All stories from epics.md are present with correct keys
  - File is valid YAML (no syntax errors)
  - Status values are legal (backlog, ready-for-dev, in-progress, review, done)
</action>
<check if="quality check fails">
  <action>Set {{status_regen_count}} = ({{status_regen_count}} or 0) + 1</action>
  <check if="{{status_regen_count}} > 2">
    <output>🚫 {status_file} still has quality issues after 2 regenerations. No story was created. Fix the file by hand, then run create-story.</output>
    <action>HALT</action>
  </check>
  <output>⚠️ Sprint status file has quality issues. Regenerating from Step 4 (regeneration {{status_regen_count}} of 2)...</output>
  <goto step="4">Regenerate sprint-status.yaml</goto>
</check>

<action>Find the FIRST story (reading top to bottom) where:
  - Key matches pattern: number-number-name (e.g., "1-1-user-auth")
  - NOT an epic key (epic-X) or retrospective (epic-X-retrospective)
  - Status value equals "backlog"
</action>

<check if="backlog story found">
  <output>📋 Sprint status validated. Now creating comprehensive story file for: {{first_backlog_story_key}}...

    The story will include exhaustive artifact analysis from PRD, architecture, UX docs, and epics.
    After story creation, self-contained atomic task files will be auto-generated.
  </output>
  <action>Read fully and follow: `{project-root}/_skad/bmm/workflows/4-implementation/create-story/workflow.md`</action>
  <note>QUALITY EXPECTATIONS for create-story:
    - Exhaustive analysis of ALL planning artifacts (PRD, architecture, UX, epics)
    - Previous story intelligence extraction (learnings, patterns, file lists)
    - Web research for latest technical specifics
    - Validation against checklist.md before finalizing
    - Story must be comprehensive enough for create-tasks to generate fully self-contained task files
  </note>
</check>

<check if="no backlog story found">
  <output>📋 Sprint status generated but no backlog stories found — all stories may already have files.

    **Next Steps:**
    1. Review {status_file} for current story statuses
    2. Run `dev-tasks` to implement the next ready-for-dev story
    3. Run `create-story` manually if you need to create a specific story
  </output>
</check>
</step>

</workflow>

## Additional Documentation

### Status State Machine

**Epic Status Flow:**

```
backlog → in-progress → done
```

- **backlog**: Epic not yet started
- **in-progress**: Epic actively being worked on (stories being created/implemented)
- **done**: All stories in epic completed

**Story Status Flow:**

```
backlog → ready-for-dev → in-progress → review → done
```

- **backlog**: Story only exists in epic file
- **ready-for-dev**: Story file created (e.g., `stories/1-3-plant-naming.md`)
- **in-progress**: Developer actively working
- **review**: Ready for code review (via Dev's code-review workflow)
- **done**: Completed

**Retrospective Status:**

```
optional ↔ done
```

- **optional**: Ready to be conducted but not required
- **done**: Finished

### Guidelines

1. **Epic Activation**: Mark epic as `in-progress` when starting work on its first story
2. **Sequential Default**: Stories are typically worked in order, but parallel work is supported
3. **Parallel Work Supported**: Multiple stories can be `in-progress` if team capacity allows
4. **Review Before Done**: Stories should pass through `review` before `done`
5. **Learning Transfer**: SM typically creates next story after previous one is `done` to incorporate learnings
