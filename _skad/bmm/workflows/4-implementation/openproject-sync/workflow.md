---
name: openproject-sync
description: 'Sync SKAD sprint status and task progress to OpenProject work packages. Called internally by dev-tasks at task-pass and story-complete boundaries. Also callable standalone: "sync openproject status".'
---

# OpenProject Sync Sub-Workflow

**Purpose:** Read `openproject-map.yaml` and `sprint-status.yaml`, then push status changes to OpenProject work packages via the MCP bridge. Also handles Task WP bootstrap (creating Task WPs when a story starts).

**Caller context variables expected (set by dev-tasks):**
- `{{op_action}}` — one of: `bootstrap-tasks` | `task-passed` | `story-complete` | `full-sync`
- `{{story_key}}` — current story key (e.g., `1-1-basic-arithmetic`)
- `{{task_file_basename}}` — current task file name (for `task-passed` action)
- `{{project_root}}` — absolute path to project root

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

## MCP CALL HELPER

`op_call` is provided by `_skad/bmm/lib/openproject-env.sh` — do **not** redefine
it here. An inline redefinition shadows the library version and loses its error
reporting, which is how an OpenProject sync can appear to run while silently
syncing nothing.

```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
op_call "test_connection" "{}" 1    # usage: op_call <tool> <args-json> [id]
```

---

## THE ONE COMMAND (prefer this to hand-written calls)

`_skad/bmm/lib/op-status.py` implements every action below against the map, so a
workflow step is one line and a status transition cannot be half-done:

```bash
python3 _skad/bmm/lib/op-status.py bootstrap <story-key>                 # ACTION: bootstrap-tasks
python3 _skad/bmm/lib/op-status.py task  <story-key> <stem> passed …     # ACTION: task-passed
python3 _skad/bmm/lib/op-status.py story <story-key> review|done …       # ACTION: story-complete
python3 _skad/bmm/lib/op-status.py check [story-key]                     # ACTION: full-sync (verifying)
python3 _skad/bmm/lib/op-status.py bug   <story-key> "<subject>" --body-file <path>
```

**`check` is the one that earns trust.** The other four write; `check` compares the
tracker against `sprint-status.yaml` and each task file's `**Status:**` line and exits 1
on any disagreement in either direction — a story closed locally but open in the tracker,
or closed in the tracker while a task file says `failed`. It was shown failing on both
before it was relied on. Run it at every story boundary; a sync that cannot fail is a
sync that will quietly stop working, which is the failure this whole workflow exists to
prevent.

The hand-written `op_call` recipes below remain accurate and are the fallback when a case
the helper does not cover comes up — a new work-package type, a relation, a custom field.
Do not redefine `op_call`; source the library.

## SHARED INITIALIZATION (run for every action)

### Load Config

```bash
CONFIG=$(cat {project-root}/_skad/bmm/config.yaml)
# Extract key fields
IMPLEMENTATION_ARTIFACTS=$(echo "$CONFIG" | python3 -c "import yaml,sys; c=yaml.safe_load(sys.stdin); print(c.get('implementation_artifacts','./implementation-artifacts'))")
```

### Load Map

```bash
OP_MAP_FILE={project-root}/_skad/bmm/openproject-map.yaml
```

Check if `openproject-map.yaml` exists:
- If NO: output `⚠️ openproject-map.yaml not found. Run create-epics-and-stories first to bootstrap OpenProject.` and RETURN (do not halt the caller).
- If YES: load it. Parse `openproject_id`, `type_ids`, `status_map`, `work_packages`.

If `openproject_id` is absent or null: output `⚠️ No openproject_id in map. Skipping OP sync.` and RETURN.

---

## ACTION: bootstrap-tasks

**Trigger:** Called from `dev-tasks` at the start of processing a new story (before Phase 1/Implement).

**Purpose:** For each task file in the current story, ensure a Task WP exists in OpenProject. Create missing ones and upload task file as attachment.

### Steps

1. **Get story WP ID** from map: `{{op_map}}.work_packages[{{story_key}}].wp_id`
   - If missing: output `⚠️ Story WP not found for {{story_key}} — run create-epics-and-stories step-05 first.` RETURN.

2. **Get task file list** from the story file's `### Task Files` section.

3. **🛑 Read the project inventory before creating any Task WP:**
   ```bash
   op_project_inventory "$OP_PROJECT_ID" || { echo "HALT: cannot verify duplicates"; exit 1; }
   ```
   The map alone is not a duplicate check — it sees only what SKAD created.

4. **For each task file:**
   a. Build task map key: `{{story_key}}/{{task_filename_no_ext}}` (e.g., `1-1-basic-arithmetic/task-1-add-function`)
   b. Check `{{op_map}}.work_packages[task_map_key]` — if `wp_id` exists, skip.
   b2. **Then check OpenProject itself**: `op_find_duplicate "$OP_PROJECT_ID" "$TASK_TITLE"` — exit 1 means adopt the existing id rather than creating a second; exit 2 means HALT.
   c. Read first line of task file to extract task title.
   d. Create Task WP:
   ```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
   RESULT=$(op_call "create_work_package" "{\"project_id\":$OP_PROJECT_ID,\"subject\":\"$TASK_TITLE\",\"type_id\":$TYPE_TASK_ID}" $CALL_ID)
   TASK_WP_ID=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))")
   ```
   e. Set parent to story WP:
   ```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
   op_call "set_work_package_parent" "{\"work_package_id\":$TASK_WP_ID,\"parent_id\":$STORY_WP_ID}" $((CALL_ID+1))
   ```
   f. Upload task file as attachment:
   ```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
   FILE_DATA=$(base64 -w 0 "$TASK_FILE_PATH")
   FILENAME=$(basename "$TASK_FILE_PATH")
   RESULT=$(op_call "add_work_package_attachment" "{\"work_package_id\":$TASK_WP_ID,\"file_data\":\"$FILE_DATA\",\"filename\":\"$FILENAME\",\"content_type\":\"text/markdown\",\"description\":\"SKAD task file\"}" $((CALL_ID+2)))
   ATTACHMENT_ID=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))")
   ```
   g. Add to map:
   ```yaml
   <story_key>/<task_name>:
     wp_id: <task_wp_id>
     parent_wp_id: <story_wp_id>
     title: <task_title>
     task_attachment_id: <attachment_id>
   ```
   h. Output: `  🔗 Task WP created: {{task_title}} → WP #{{task_wp_id}}`

4. **Save updated openproject-map.yaml.**

---

## ACTION: task-passed

**Trigger:** Called from `dev-tasks` immediately after a task file Status is set to `passed`.

**Purpose:** Update the Task WP status in OpenProject to the "done/closed" status.

### Steps

1. Build task map key: `{{story_key}}/{{task_name_no_ext}}`
2. Look up `wp_id` from map.
3. If not found: output `⚠️ No WP found for task {{task_file_basename}}. Skipping.` RETURN.
4. Get `passed` status ID from `status_map`.
5. Update WP status:
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
RESULT=$(op_call "update_work_package_status" "{\"work_package_id\":$TASK_WP_ID,\"status_id\":$PASSED_STATUS_ID,\"comment\":\"Task passed all phases (implement → review → test) in SKAD dev-tasks.\"}" $CALL_ID)
```
6. Output: `  🔗 OP updated: Task WP #{{task_wp_id}} → done`
7. Save map (no changes to map needed for status updates — WP ID is already recorded).

---

## ACTION: story-complete

**Trigger:** Called from `dev-tasks` after all tasks in a story have passed and story Status is set to `review`.

**Purpose:** Update Story WP status to "In Review". Upload updated story file. Check if all stories in the epic are review/done → update Epic WP status accordingly.

### Steps

1. **Update Story WP status:**
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
STORY_WP_ID=$(get_from_map "$STORY_KEY.wp_id")
REVIEW_STATUS_ID=$(get_from_map "status_map.review")
RESULT=$(op_call "update_work_package_status" "{\"work_package_id\":$STORY_WP_ID,\"status_id\":$REVIEW_STATUS_ID,\"comment\":\"All tasks passed in SKAD dev-tasks. Story is in review.\"}" $CALL_ID)
```
   Output: `  🔗 OP updated: Story WP #{{story_wp_id}} → in-review`

2. **Upload updated story file** (overwrite old attachment):
```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
STORY_FILE_PATH="$IMPLEMENTATION_ARTIFACTS/$STORY_KEY.md"
FILE_DATA=$(base64 -w 0 "$STORY_FILE_PATH")
RESULT=$(op_call "add_work_package_attachment" "{\"work_package_id\":$STORY_WP_ID,\"file_data\":\"$FILE_DATA\",\"filename\":\"$STORY_KEY.md\",\"content_type\":\"text/markdown\",\"description\":\"SKAD story file (updated after all tasks passed)\"}" $((CALL_ID+1)))
```
   Store new attachment ID: `{{op_map}}.work_packages[{{story_key}}].story_attachment_id = <new_attachment_id>`

3. **Check Epic completion:**
   - Find the epic key for this story: look at `{{op_map}}.work_packages[{{story_key}}].parent_wp_id`, then reverse-lookup the epic key.
   - Load `sprint-status.yaml`. Find all story keys belonging to this epic (keys matching `<epic_num>-*`).
   - Check if ALL stories are status `review` or `done` in sprint-status.
   - If YES (all stories review/done):
     - Get Epic WP ID from map.
     - Update Epic WP status to `in_progress` (all stories done = epic is fully in review):
     ```bash
source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
     op_call "update_work_package_status" "{\"work_package_id\":$EPIC_WP_ID,\"status_id\":$IN_PROGRESS_STATUS_ID,\"comment\":\"All stories in this epic have completed dev-tasks.\"}" $CALL_ID
     ```
     - Output: `  🔗 OP updated: Epic WP #{{epic_wp_id}} → in-progress (all stories complete)`

4. **Save updated openproject-map.yaml.**

---

## ACTION: full-sync

**Trigger:** Called standalone (`sync openproject status`) or as a repair operation.

**Purpose:** Read the complete sprint-status.yaml and all task files, then bring OpenProject fully in sync with local state.

### Steps

1. Load `sprint-status.yaml`. For each entry in `development_status`:
   - Skip entries that aren't in `op_map.work_packages`.
   - Map local status → OP status ID using `status_map`.
   - Call `update_work_package_status` for each WP that has a different status.

2. For each story key found in map:
   - Check if story file exists and has a `Status:` field.
   - Sync story WP status accordingly.

3. For each task key found in map:
   - Check task file `Status:` field.
   - Sync task WP status accordingly.

4. Output a sync summary table:
```
🔄 OpenProject Full Sync Complete

| Entity | Key | Local Status | OP Status | Updated |
|--------|-----|-------------|-----------|---------|
| Epic   | epic-1 | backlog | new | no |
| Story  | 1-1-basic-arithmetic | review | in-review | yes |
| Task   | .../task-1-add-function | passed | closed | yes |
```

---

## ERROR HANDLING

For any MCP call failure:
- Parse the error from the response: check for `error` key in JSON-RPC response.
- Output: `⚠️ OP sync warning: [tool_name] failed — {{error_message}}. Continuing dev-tasks.`
- **Never halt the dev-tasks pipeline** due to OP sync failures — sync is best-effort.
- Log the failure details for later `full-sync` repair.
