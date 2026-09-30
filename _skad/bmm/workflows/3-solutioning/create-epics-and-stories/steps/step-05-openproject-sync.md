---
name: 'step-05-openproject-sync'
description: 'Bootstrap OpenProject project and push epics/stories as work packages with artifact attachments'

# Path Definitions
workflow_path: '{project-root}/_skad/bmm/workflows/3-solutioning/create-epics-and-stories'
op_endpoint_source: 'config.yaml:openproject_mcp_url'   # NOT a literal - resolved at run time

# File References
thisStepFile: './step-05-openproject-sync.md'
configFile: '{project-root}/_skad/bmm/config.yaml'
opMapFile: '{project-root}/_skad/bmm/openproject-map.yaml'
outputFile: '{planning_artifacts}/epics.md'
skillDir: '{project-root}/.claude/skills/openproject'
---

# Step 5: OpenProject Sync

## STEP GOAL

Bootstrap the OpenProject project, create Epic and Story work packages in the correct hierarchy, upload `epics.md` as an artifact, and write `openproject-map.yaml` as the permanent ID registry. Self-install the OpenProject Claude skill if not present.

## MANDATORY RULES

- 🟡 If OpenProject is unreachable: warn clearly and HALT gracefully — do NOT fail silently
- 🔁 If `openproject-map.yaml` already contains IDs for an epic or story, UPDATE (do not create duplicates)
- 💾 Write all created WP IDs to `openproject-map.yaml` before finishing
- 🔑 All calls use the MCP JSON-RPC endpoint via `curl` through the Bash tool
- 📋 Communicate in {communication_language} tailored to {user_skill_level}

---

## ENDPOINT RESOLUTION (MANDATORY — read before any MCP call)

The endpoint is **configuration, not a constant**. It lives in
`_skad/bmm/config.yaml` as `openproject_mcp_url`. Never hard-code it here.

**Every bash block that talks to OpenProject MUST start with:**

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
```

Each Bash tool invocation is a **fresh shell** — shell variables do not survive
between blocks of a workflow, so re-sourcing in every block is the only thing
that works. Sourcing defines `$OP_MCP_URL`, `$OP_TIMEOUT`, `$OP_PROJECT_ID`,
`$OP_AUTH_ARGS` and the `op_call` helper.

`op_call <tool> <args-json> [id]` prints the tool result on success and returns
non-zero on failure. It bounds every call with `-m "$OP_TIMEOUT"` (rule 4) and
reports transport failures, non-200 responses and `isError:true` tool failures
to stderr naming the consequence — "Status NOT synced" (rule 6). **Check its
exit status; an empty stdout means the call failed, not that nothing needed
doing.**

---

## MCP CALL PATTERN

Use this pattern for ALL OpenProject tool calls:

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
op_call "<TOOL>" "<ARGS_JSON>" <ID>
```

Parse the response:
```bash
# Get the result text (a JSON string)
# op_call already unwrapped result.content[0].text and verified the envelope,
# so $RESPONSE is the tool's own JSON. Do NOT unwrap it again.
RESULT="$RESPONSE"
# Pretty-print it
echo "$RESULT" | python3 -m json.tool
```

---

## EXECUTION

### Phase 0 — Self-Install Claude Skill

Ensure the OpenProject Claude skill is present in the target project so future conversations have OP awareness.

```bash
# Check if the skill already exists
ls {project-root}/.claude/skills/openproject/SKILL.md 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

If EXISTS: skip this phase.

If MISSING, try in order:

**Option A — OpenProject module was installed via `skad install`:**
```bash
# Check if module skill files are present in the installed module
ls {project-root}/_skad/openproject/claude-skills/openproject/SKILL.md 2>/dev/null && echo "MODULE_PRESENT" || echo "MODULE_ABSENT"
```
If MODULE_PRESENT:
```bash
mkdir -p {project-root}/.claude/skills/openproject/prompts
cp -r {project-root}/_skad/openproject/claude-skills/openproject/. {project-root}/.claude/skills/openproject/
```

**Option B — Write inline (module not installed):**
Create `{project-root}/.claude/skills/openproject/prompts/` directory, then write two files:

`{project-root}/.claude/skills/openproject/SKILL.md`:
```markdown
---
name: openproject
description: >
  OpenProject MCP bridge. Interact with the OpenProject project management
  instance configured at _skad/bmm/config.yaml:openproject_mcp_url.
  Use when the user asks about
  projects, work packages, tasks, stories, epics, bugs, sprints, time logging,
  assignees, relations, watchers, attachments, or any OpenProject / PM
  operations. Also activate proactively when you detect a need to create,
  update, or query project management data. Do NOT load full context unless
  this skill is explicitly invoked or a clear PM action is required.
---

Read `prompts/instructions.md` and execute.
```

`{project-root}/.claude/skills/openproject/prompts/instructions.md`:
Write a minimal stub:
```markdown
# OpenProject MCP Bridge

**Endpoint:** read `openproject_mcp_url` from `_skad/bmm/config.yaml`
**Protocol:** JSON-RPC 2.0 over HTTPS POST (44 tools available)

## Call Pattern
Use Bash tool with curl:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
op_call "<TOOL>" "<ARGS>" 1
```

Key tools: test_connection, list_projects, get_project, create_project,
list_work_packages, create_work_package, update_work_package, delete_work_package,
update_work_package_status, set_work_package_parent, bulk_create_work_packages,
add_work_package_attachment, list_users, log_time, list_statuses, list_types.

For the full 44-tool catalog, run `skad install openproject` to install the complete skill.
```
```

Output: `✅ OpenProject Claude skill installed at .claude/skills/openproject/`

---

### Phase 1 — Test Connectivity

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
RESPONSE=$(op_call "test_connection" "{}" 1) || {
  echo "FAIL: op_call reported the failure above. OpenProject is NOT reachable."
  exit 1
}
echo "$RESPONSE" | python3 -c "import json,sys; r=json.load(sys.stdin); print('OK' if r.get('success') else 'FAIL: '+str(r.get('message','unknown')))"
```

- If result is `FAIL`: output a clear warning with the failure reason, then offer:
  - [R] Retry — try connecting again
  - [S] Skip — complete the workflow without OpenProject sync
  If user selects S: output "⚠️ OpenProject sync skipped. You can run it later with `sync openproject status`."
  Then: Read fully and follow: `{project-root}/_skad/core/tasks/help.md`
- If result is `OK`: continue to Phase 2.

---

### Phase 2 — Ensure OpenProject Project

Read `{project-root}/_skad/bmm/config.yaml`. Extract `openproject_id`.

**If `openproject_id` is present (not null, not empty):**
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
# Verify project exists
if [ -z "$OP_PROJECT_ID" ]; then
  echo "NO_PROJECT_ID"          # nothing configured — go create one
else
  # IMPORTANT: distinguish "the project is not there" from "the call failed".
  # Treating a transport or auth failure as "not found" creates a DUPLICATE
  # project on every run against a configured, working instance.
  RESPONSE=$(op_call "get_project" "{\"project_id\":$OP_PROJECT_ID}" 2) \
    && echo "FOUND" \
    || echo "LOOKUP_FAILED"
fi
```
- `FOUND` → use it. Set `{{op_project_id}}` = the confirmed ID. **Do not create anything.**
- `NO_PROJECT_ID` → no `openproject_id` is configured; continue to project creation below.
- `LOOKUP_FAILED` → **HALT. Do NOT create a project.** The call failed, which is not
  the same as the project being absent — creating one here duplicates a project that
  may well exist. Report the error `op_call` printed and stop.

**Only when the branch above printed `NO_PROJECT_ID`** — never after `LOOKUP_FAILED`:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
# Create the project
IDENTIFIER=$(echo "{project_name}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-25)
RESPONSE=$(op_call "create_project" "{\"name\":\"{project_name}\",\"identifier\":\"$IDENTIFIER\",\"description\":\"Generated by SKAD-Method BMM workflow\",\"public\":false}" 3)
```
- Extract `id` from result.
- Set `{{op_project_id}}` = newly created project ID.
- **Write `openproject_id: {{op_project_id}}` into `_skad/bmm/config.yaml`** (append or update the field).

---

### Phase 3 — Resolve Type IDs

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
RESPONSE=$(op_call "list_types" "{\"project_id\":$OP_PROJECT_ID}" 4)
```

Parse the types list. Match (case-insensitive):
- **Initiative type**: first match of "Initiative" — this carries the SOLUTION GOALS, the
  topmost level, above every epic.
- **Epic type**: first match of "Epic"
- **Story type**: first match of "User Story", "Story", or "Feature"
- **Task type**: first match of "Task"

Store as `{{type_initiative_id}}`, `{{type_epic_id}}`, `{{type_story_id}}`, `{{type_task_id}}`.

If any type is NOT found, warn: "Type '{{name}}' not found in OpenProject — using default type (null). Epics/Stories/Tasks will be created as the default work package type."

---

### Phase 4 — Resolve Status IDs

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
RESPONSE=$(op_call "list_statuses" "{}" 5) || exit 1
```

Build a status map (local → OpenProject status ID). **Match in three passes, in
order:** exact name (case-insensitive), then substring either way, then the
listed fallback.

| Local status | Candidates, in preference order |
|---|---|
| `backlog` / `ready_for_dev` / `ready_for_task` | `New`, `Backlog`, `Open`, `To be scheduled`, `Scheduled` |
| `in_progress` / `in_dev` | `In progress`, `In development`, `In specification`, `Specified` |
| `review` / `in_review` / `in_test` | `In review`, `Under review`, `In testing`, `Testing`, `Tested`, `Developed`, `Confirmed` |
| `done` / `passed` | `Closed`, `Done`, `Resolved`, `Tested` |
| `failed` | `Rejected`, `Failed`, `Cancelled`, `Test failed`, `On hold` |

**A default OpenProject instance does not use SKAD's vocabulary.** A stock install
ships `In specification`, `Specified`, `Developed`, `In testing`, `Tested`,
`Test failed` — and **none of them is an exact match for `review`**. That is why
substring matching and the widened candidate lists exist: without them the
`review` transition resolves to nothing.

**🛑 An unmapped status MUST be reported, not skipped.** Print every local status
that resolved to nothing, name the consequence, and ask the operator to choose a
target from the instance's actual status list before continuing:

```
⚠️  OpenProject: local status "review" matched no status on this instance.
    Available: <list>
    Consequence: stories reaching review will NOT sync — their work package
    stays at its previous status and nothing reports the gap.
```

*Sync is best-effort and must never halt `dev-tasks` — but "best-effort" means the
failure is **visible**, not that it is silent. A status that quietly never
transitions looks identical to a story nobody moved.*

Store as `{{status_map}}` (a dict of local_name → op_status_id), and record any
unmapped local status in the map file as `null` so the gap is inspectable later.

---

### Phase 5 — Load or Initialize Map

Check if `{project-root}/_skad/bmm/openproject-map.yaml` exists:
- If YES: load it into `{{op_map}}`.
- If NO: initialize `{{op_map}}` as an empty map structure:

```yaml
# Auto-generated by SKAD-BMM OpenProject Sync — do not edit manually
openproject_id: <op_project_id>
type_ids:
  initiative: <type_initiative_id>
  epic: <type_epic_id>
  story: <type_story_id>
  task: <type_task_id>
status_map:
  backlog: <id>
  ready_for_dev: <id>
  in_progress: <id>
  review: <id>
  done: <id>
  failed: <id>
  ready_for_task: <id>
  in_dev: <id>
  in_dev_complete: <id>
  in_review: <id>
  in_test: <id>
  passed: <id>
work_packages: {}
```

---

### Phase 5a — 🛑 MANDATORY duplicate check — read OpenProject BEFORE creating anything

**Never create an epic, feature, story or task without first reading what the
project already contains.** Not the map — **OpenProject**.

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
COUNT=$(op_project_inventory "$OP_PROJECT_ID") || {
  echo "HALT: could not read the project inventory. Creating now risks duplicates."
  exit 1
}
echo "Project $OP_PROJECT_ID currently holds $COUNT work packages."
```

**Then, for every epic and story you are about to create:**

```bash
op_find_duplicate "$OP_PROJECT_ID" "$SUBJECT"
case $? in
  0) : ;;                                  # checked, none — safe to create
  1) echo "DUPLICATE — adopt the existing id, do NOT create"; ;;
  2) echo "COULD NOT CHECK — HALT"; exit 1 ;;
esac
```

**Why the map is not enough.** `openproject-map.yaml` records only what SKAD
itself created. It cannot see a work package made by hand, by another tool, by a
teammate, or by an earlier run whose map was lost. **Checking the map and calling
that a duplicate check is verifying against our own record rather than the system
of record** — and the map is precisely the file most likely to be missing when it
matters.

**The three outcomes are deliberately different exit codes**, because *"I looked
and found nothing"* and *"I could not look"* must never be confused. **A failed
check must never read as permission to create.**

**On a duplicate: adopt, do not create.** Record the existing `wp_id` in the map
and continue. Two work packages for one story is worse than none — the second
splits the history, and status sync then updates whichever one the map happens to
point at.

**Pagination is not optional.** The API returns 20 per page. Reading the first
page and treating it as the project is how a duplicate check reports "not found"
for something on page 2. `op_project_inventory` pages until the count matches the
reported total and **refuses** if it cannot.

---

### Phase 6 — Parse Epics & Stories from epics.md

Read `{planning_artifacts}/epics.md`.

Extract the epic/story hierarchy by scanning for:
- Epic headers: `## Epic N: <title>` — sets `{{epic_key}}` = `epic-N`, `{{epic_title}}`
- Story headers: `### Story N.M: <title>` — sets `{{story_key}}` = `N-M-<slug>`, `{{story_title}}`
  - `<slug>` = kebab-case of the story title (max 40 chars, lowercase, hyphens only)

Build `{{epics_stories}}` list:
```
[
  { key: "epic-1", title: "Epic 1: ...", stories: [
      { key: "1-1-story-slug", title: "Story 1.1: ...", epic_key: "epic-1" },
      ...
  ]},
  ...
]
```

---

### Phase 7 — Create Epic Work Packages

### The Initiative — the GOAL, the root of the hierarchy

Create this BEFORE any epic. It holds the GOAL and its capabilities, and every epic hangs from it, so
the chain from a goal down to a task is walkable in the tracker by someone who has read none
of the planning artifacts.

1. Check `{{op_map}}.work_packages["initiative"]` — if `wp_id` exists, skip creation.
2. If NOT in map, and `{{type_initiative_id}}` resolved:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
RESPONSE=$(op_call "create_work_package" "{\"project_id\":$OP_PROJECT_ID,\"subject\":\"<solution name> — GOAL\",\"type_id\":$TYPE_INITIATIVE_ID}" <ID>)
```
3. Its DESCRIPTION is the GOAL and the Capabilities → GOAL table, taken from the product brief (`product-brief-<project>-<date>.md` in `{planning_artifacts}/`) — not a link to them, and not a summary of the epics beneath
   it. A goal written so it cannot be judged met makes every rung below it unverifiable, and
   this is the one level where that cannot be caught from underneath.
4. Attach the PRD brief to it: `add_work_package_attachment`. This gives the agreed spec one
   fixed address, which is what makes "do not deviate from the spec" checkable rather than
   aspirational.
5. Store in map: `{{op_map}}.work_packages["initiative"].wp_id = <id>`, and record which
   document the GOAL and each capability came from.
6. Output: `✅ Initiative WP created: <subject> → WP #{{id}} (GOAL + capabilities, PRD attached)`

**If `{{type_initiative_id}}` did not resolve**, do NOT silently create the epics without a
root: report `⚠️ No Initiative type in this OpenProject instance — the solution-goal rung
cannot be created, so epics will have no root to be checked against`, and say it again in
the step's final output. A hierarchy missing its top level and one that never had a top
level must not look the same.

---

For each epic in `{{epics_stories}}`:

1. Check `{{op_map}}.work_packages[epic.key]` — if `wp_id` exists, skip creation (already synced).
2. If NOT in map:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
RESPONSE=$(op_call "create_work_package" "{\"project_id\":$OP_PROJECT_ID,\"subject\":\"<epic.title>\",\"type_id\":$TYPE_EPIC_ID}" <ID>)
```
3. Extract `id` from result. Store in map: `{{op_map}}.work_packages[epic.key].wp_id = <id>`.
4. Parent it to the Initiative, so the epic hangs from the goals it serves:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
op_call "set_work_package_parent" "{\"work_package_id\":$EPIC_WP_ID,\"parent_id\":$INITIATIVE_WP_ID}" <ID>
```
   Skip only when no Initiative exists, and then carry the warning above into this step's output.
   **This runs for every epic — the ones just created AND the ones already in the map.** A
   project synced before the Initiative existed has epics with no parent, and "skip creation"
   at step 1 means skip CREATING the work package, never skip parenting it. Re-derive
   `EPIC_WP_ID` from `{{op_map}}.work_packages[epic.key].wp_id` for those, exactly as Phase 8
   already does, and parent them now. Otherwise the section's own claim that every epic hangs
   from the Initiative is false for precisely the projects that predate it.
5. Record which capability(ies) this epic serves, in the map beside its id:
   `{{op_map}}.work_packages[epic.key].serves = [<capability ids>]`. An epic serving
   none is not an oversight to fix later — it is work nobody asked for, and it is cheapest to
   catch here, before it is built.
6. Output: `✅ Epic WP created: {{epic.title}} → WP #{{id}} (child of Initiative #{{initiative_wp_id}}, serves {{serves}})`

---

### Phase 8 — Upload epics.md to Each Epic WP

For each epic that was just created OR already existed in the map:

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
# Base64-encode the epics.md file
FILE_DATA=$(base64 -w 0 "{planning_artifacts}/epics.md")
EPIC_WP_ID={{op_map.work_packages[epic.key].wp_id}}

RESPONSE=$(op_call "add_work_package_attachment" "{\"work_package_id\":$EPIC_WP_ID,\"file_data\":\"$FILE_DATA\",\"filename\":\"epics.md\",\"content_type\":\"text/markdown\",\"description\":\"SKAD epics and stories breakdown\"}" <ID>)
```

Extract `attachment_id` from result. Store: `{{op_map}}.work_packages[epic.key].epics_attachment_id = <attachment_id>`.

---

### Phase 9 — Create Story Work Packages

For each story in `{{epics_stories}}`:

1. Check `{{op_map}}.work_packages[story.key]` — if `wp_id` exists, skip creation.
2. Get `{{parent_wp_id}}` = `{{op_map}}.work_packages[story.epic_key].wp_id`
3. If NOT in map:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
RESPONSE=$(op_call "create_work_package" "{\"project_id\":$OP_PROJECT_ID,\"subject\":\"<story.title>\",\"type_id\":$TYPE_STORY_ID}" <ID>)
```
4. Extract `id`. Then set parent:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
op_call "set_work_package_parent" "{\"work_package_id\":$STORY_WP_ID,\"parent_id\":$PARENT_WP_ID}" <ID>
```
5. Store in map:
```yaml
<story.key>:
  wp_id: <story_wp_id>
  parent_wp_id: <epic_wp_id>
  title: <story.title>
```
6. Output: `  ✅ Story WP created: {{story.title}} → WP #{{id}} (child of Epic #{{parent_wp_id}})`

### Dependency links

Parenting records the hierarchy. It does NOT record that one item must wait for another — an epic
building email templates being unable to start before the epic that stands up the mail system is a
different relation, and it is the one the pipeline reads. Create it for every `hard:` entry in a
`Depends on:` field, after all work packages exist (both ends must, or the link cannot be made).

**The relation tool is not guaranteed to be installed.** The base catalog here is
`test_connection, list_projects, get_project, create_project, list_work_packages,
create_work_package, update_work_package, delete_work_package, update_work_package_status,
set_work_package_parent, bulk_create_work_packages, add_work_package_attachment, list_users,
log_time, list_statuses, list_types` — no relation tool among them; the full 44-tool catalog
(`skad install openproject`) has one. So DISCOVER it, never assume its name:

`op_call` can only invoke a NAMED tool — it hardcodes `"method":"tools/call"`
(`_skad/bmm/lib/openproject-env.sh`), so it cannot send the MCP protocol's own
`tools/list`. There is no discovery call to make through it. Establish what exists
from the install instead:

- Read the installed skill's tool catalog, `.claude/skills/openproject/prompts/instructions.md`.
  The base install documents 16 tools and no relation tool; the full catalog
  (`skad install openproject`) documents more.
- If that catalog names a relation tool, use THAT name and read its argument schema
  from the same file. Do not guess a name, and do not probe by calling a guessed one —
  an unknown tool returns an error that looks the same as a server fault, and you
  would be reading a failure as an answer.
- If it names none, you have NOT established absence — that block is headed "Key tools:", not "All
  tools", and its own header says "44 tools available" while listing 16. A partial list proves
  nothing either way. Record the relation tool as UNCONFIRMED, take the fallback below, and say
  `unconfirmed` rather than `absent` in the output and the map. Do not resolve the ambiguity by
  calling a guessed tool name: an unknown tool and a server fault return the same error, so a probe
  would read a failure as an answer.

Record which of the two you established, and from which file, beside the counts.

- **If a relation tool exists**, create one link per hard dependency, in the direction "the dependency
  PRECEDES the dependent" (`precedes`/`follows`, or `blocks`/`blocked by` — use whichever the tool's
  own schema defines; read the schema, do not guess the field names), from the dependency's `wp_id`
  to the dependent's. Record it in the map beside the item:
  ```yaml
  <item.key>:
    wp_id: <id>
    depends_on: [{key: <dependency.key>, wp_id: <id>, kind: hard, relation_id: <id>}]
  ```
- **If no relation tool exists**, do NOT skip silently. Write each hard dependency into the
  dependent's description as a line `Depends on (hard): <key> — WP #<id>`, record
  `depends_on: [{key: …, wp_id: …, kind: hard, relation_id: null, reason: "relation tool absent or unconfirmed — say which"}]` in
  the map, and say so in this step's output: `⚠️ N hard dependencies recorded in descriptions only —
  no relation tool is confirmed installed, so nothing in OpenProject enforces the ordering.`
  A missing link and a link that was never needed must not look the same.
- **A hard dependency whose other end has no work package** is an error, not a skip: report the item
  and the dependency key, and do not claim the sync completed.

Output a count either way: `  ✅ Dependency links: {{created}} created, {{described}} recorded in
descriptions, {{failed}} unresolved`. Compute the three; never state them.

---

### Phase 10 — Save openproject-map.yaml

Write the complete `{{op_map}}` to `{project-root}/_skad/bmm/openproject-map.yaml`.

Include a header comment:
```yaml
# Auto-generated by SKAD-BMM OpenProject Sync
# Managed by: create-epics-and-stories step-05 and openproject-sync workflow
# Do not edit manually — values are updated automatically during dev workflow
```

---

### Phase 11 — Completion Report

Output a summary:

```
🔗 OpenProject Sync Complete

Project:    {project_name} → OP Project #{{op_project_id}}
Epics:      {{epic_count}} work packages created/verified
Stories:    {{story_count}} work packages created/verified
Artifacts:  epics.md uploaded to each epic WP
Map saved:  _skad/bmm/openproject-map.yaml

Next: Run create-story → create-tasks → dev-tasks
      Status will sync to OpenProject automatically as tasks progress.
```

Workflow complete. Read fully and follow: `{project-root}/_skad/core/tasks/help.md`
