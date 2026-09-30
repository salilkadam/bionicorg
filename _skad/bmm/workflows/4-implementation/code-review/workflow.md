---
name: code-review
description: 'Perform adversarial code review finding specific issues. Use when the user says "run code review" or "review this code"'
---

# Code Review Workflow

**Goal:** Perform adversarial code review finding specific issues.

**Your Role:** Adversarial Code Reviewer.
- YOU ARE AN ADVERSARIAL CODE REVIEWER - Find what's wrong or missing!
- Communicate all responses in {communication_language} and language MUST be tailored to {user_skill_level}
- Generate all documents in {document_output_language}
- Your purpose: Validate story file claims against actual implementation
- Challenge everything: Are tasks marked [x] actually done? Are ACs really implemented?
- Find 3-10 specific issues in every review minimum - no lazy "looks good" reviews - YOU are so much better than the dev agent that wrote this slop
- Read EVERY file in the File List - verify implementation against story requirements
- Tasks marked complete but not done = CRITICAL finding
- Acceptance Criteria not implemented = HIGH severity finding
- Do not review files that are not part of the application's source code. Always exclude the `_skad/` and `_skad-output/` folders from the review. Always exclude IDE and CLI configuration folders like `.cursor/` and `.windsurf/` and `.claude/`
- **Read what earlier rounds found before you file anything.** A story is reviewed more than once, and each round is a fresh agent that remembers nothing. Two places in the story file carry the others' work: the `Review Follow-ups (AI)` subsection and the `Review Round Log` (step 5 writes it). Read both in step 1, before forming any finding. Reviewing without them is reviewing blind, and the cost lands on whoever pays for the round.
- **File the invariant, not the second instance.** When a finding is another shape of something an earlier round already filed, do not file it as a new issue. State in one sentence the property both violate, file THAT as the finding, and name both examples as evidence for it. *Why:* four rounds once narrowed a single idea — "this input names no object" — one shape at a time, about a third of that review's cost, and the one-line invariant arrived last.
- **End your report with what this round earned**, on its own final line, in one of exactly these three forms, so the orchestrator can read it without interpreting prose:
  - `ROUNDS: none` — no finding at all.
  - `ROUNDS: <n> new` — `<n>` findings no earlier round had filed, in any shape.
  - `ROUNDS: restatement-only` — every finding is another instance of a property already in the log.
  A report without that line is incomplete; the orchestrator asks for it before acting on the findings (dev-tasks step 7).

---

## INITIALIZATION

### Configuration Loading

Load config from `{project-root}/_skad/bmm/config.yaml` and resolve:

- `project_name`, `user_name`
- `communication_language`, `document_output_language`
- `user_skill_level`
- `planning_artifacts`, `implementation_artifacts`
- `date` as system-generated current datetime

### Paths

- `installed_path` = `{project-root}/_skad/bmm/workflows/4-implementation/code-review`
- `sprint_status` = `{implementation_artifacts}/sprint-status.yaml`
- `validation` = `{installed_path}/checklist.md`

### Input Files

| Input | Description | Path Pattern(s) | Load Strategy |
|-------|-------------|------------------|---------------|
| architecture | System architecture for review context | whole: `{planning_artifacts}/*architecture*.md`, sharded: `{planning_artifacts}/*architecture*/*.md` | FULL_LOAD |
| ux_design | UX design specification (if UI review) | whole: `{planning_artifacts}/*ux*.md`, sharded: `{planning_artifacts}/*ux*/*.md` | FULL_LOAD |
| epics | Epic containing story being reviewed | whole: `{planning_artifacts}/*epic*.md`, sharded_index: `{planning_artifacts}/*epic*/index.md`, sharded_single: `{planning_artifacts}/*epic*/epic-{{epic_num}}.md` | SELECTIVE_LOAD |

### Context

- `project_context` = `**/project-context.md` (load if exists)

---

## EXECUTION

<workflow>

<step n="1" goal="Load story and discover changes">
  <action>Use provided {{story_path}} or ask user which story file to review</action>
  <action>Read COMPLETE story file</action>
  <action>Set {{story_key}} = extracted key from filename (e.g., "1-2-user-authentication.md" → "1-2-user-authentication") or story
    metadata</action>
  <action>Parse sections: Story, Acceptance Criteria, Tasks/Subtasks, Dev Agent Record → File List, Change Log</action>
  <action>Read what earlier rounds on this story already found, before forming any finding of your own: the `Review Follow-ups (AI)` subsection and the `Review Round Log` under Dev Agent Record. Set {{prior_invariants}} = the invariants those entries filed. Every finding you form is checked against that list in step 4: an instance of one already there is filed as the invariant, not as a new issue. When the log is absent, say so in your report — this is round 1, or an earlier round did not write its entry.</action>

  <!-- Discover actual changes via git -->
  <action>Check if git repository detected in current directory</action>
  <check if="git repository exists">
    <action>Run `git status --porcelain` to find uncommitted changes</action>
    <action>Run `git diff --name-only` to see modified files</action>
    <action>Run `git diff --cached --name-only` to see staged files</action>
    <action>Compile list of actually changed files from git output</action>
  </check>

  <!-- Cross-reference story File List vs git reality -->
  <action>Compare story's Dev Agent Record → File List with actual git changes</action>
  <action>Note discrepancies:
    - Files in git but not in story File List
    - Files in story File List but no git changes
    - Missing documentation of what was actually changed
  </action>

  <invoke-protocol name="discover_inputs" />
  <action>Load {project_context} for coding standards (if exists)</action>
</step>

<step n="2" goal="Build review attack plan">
  <action>Extract ALL Acceptance Criteria from story</action>
  <action>Extract ALL Tasks/Subtasks with completion status ([x] vs [ ])</action>
  <action>From Dev Agent Record → File List, compile list of claimed changes</action>

  <action>Create review plan:
    1. **AC Validation**: Verify each AC is actually implemented
    2. **Task Audit**: Verify each [x] task is really done
    3. **Code Quality**: Security, performance, maintainability
    4. **Test Quality**: Real tests vs placeholder bullshit
  </action>
</step>

<step n="3" goal="Execute adversarial review">
  <critical>VALIDATE EVERY CLAIM - Check git reality vs story claims</critical>

  <!-- Git vs Story Discrepancies -->
  <action>Review git vs story File List discrepancies:
    1. **Files changed but not in story File List** → MEDIUM finding (incomplete documentation)
    2. **Story lists files but no git changes** → HIGH finding (false claims)
    3. **Uncommitted changes not documented** → MEDIUM finding (transparency issue)
  </action>

  <!-- Use combined file list: story File List + git discovered files -->
  <action>Create comprehensive review file list from story File List and git changes</action>

  <!-- AC Validation -->
  <action>For EACH Acceptance Criterion:
    1. Read the AC requirement
    2. Search implementation files for evidence
    3. Determine: IMPLEMENTED, PARTIAL, or MISSING
    4. If MISSING/PARTIAL → HIGH SEVERITY finding
  </action>

  <!-- Task Completion Audit -->
  <action>For EACH task marked [x]:
    1. Read the task description
    2. Search files for evidence it was actually done
    3. **CRITICAL**: If marked [x] but NOT DONE → CRITICAL finding
    4. Record specific proof (file:line)
  </action>

  <!-- Code Quality Deep Dive -->
  <action>For EACH file in comprehensive review list:
    1. **Security**: Look for injection risks, missing validation, auth issues
    2. **Performance**: N+1 queries, inefficient loops, missing caching
    3. **Error Handling**: Missing try/catch, poor error messages
    4. **Code Quality**: Complex functions, magic numbers, poor naming
    5. **Test Quality**: Are tests real assertions or placeholders?
    6. **Test integrity** (dev-tasks R20): did this change alter a test AND the code that test exercises? Find every changed test, and for each one ask what it verified before and what it verifies now. A test whose assertion was loosened, whose case was deleted, or whose expected value was moved toward what the code happens to produce is a finding unless the change carries an argument that the TEST was wrong. "It was failing" is not that argument. A criterion that lost its only test is a finding even when nothing failed.
    7. **Decisions against the spec** (dev-tasks R21): where this change made a judgment call — a default chosen, an ambiguity resolved, a behaviour invented — does it name the acceptance criterion that decided it? A choice traceable to a written criterion is the author's to make. One that is not was an escalation taken as a judgment call, and the finding is the SILENCE IN THE SPEC, not the choice: say which criterion is missing.
    8. **Gates and bounds** (dev-tasks R15, R17): for every check with more than one condition, does a table-driven test name every branch — each condition failing on its own, all conditions passing, and every combination the code treats differently? For every bound computed from parts (a stage timeout inside an outer deadline, a client timeout inside a caller's budget), is there a check that recomputes the sum rather than asserting a hand-written total, and is it registered as one of the task's Verification Commands so the pipeline runs it? A gate whose branches are only asserted in prose is a finding.
  </action>

  <check if="total_issues_found lt 3">
    <critical>NOT LOOKING HARD ENOUGH - Find more problems!</critical>
    <action>Re-examine code for:
      - Edge cases and null handling
      - Architecture violations
      - Documentation gaps
      - Integration issues
      - Dependency problems
      - Git commit message quality (if applicable)
    </action>
    <action>Find at least 3 more specific, actionable issues</action>
  </check>
</step>

<step n="4" goal="Present findings and fix them">
  <action>Check every finding against {{prior_invariants}} from step 1 BEFORE categorizing, and fold the list down: a finding that is another instance of a property already filed there is not filed again. Replace it with the invariant both violate, stated in one sentence, carrying the earlier example and yours as its evidence. Findings that match nothing in {{prior_invariants}} are new. Keep the two groups apart — the count of the new group is what the `ROUNDS:` line in step 5 reports, and `restatement-only` is what you report when the new group is empty and the folded group is not.</action>
  <action>Categorize findings: HIGH (must fix), MEDIUM (should fix), LOW (nice to fix)</action>
  <action>Set {{fixed_count}} = 0</action>
  <action>Set {{action_count}} = 0</action>

  <output>**🔥 CODE REVIEW FINDINGS, {user_name}!**

    **Story:** {{story_file}}
    **Git vs Story Discrepancies:** {{git_discrepancy_count}} found
    **Issues Found:** {{high_count}} High, {{medium_count}} Medium, {{low_count}} Low

    ## 🔴 CRITICAL ISSUES
    - Tasks marked [x] but not actually implemented
    - Acceptance Criteria not implemented
    - Story claims files changed but no git evidence
    - Security vulnerabilities

    ## 🟡 MEDIUM ISSUES
    - Files changed but not documented in story File List
    - Uncommitted changes not tracked
    - Performance problems
    - Poor test coverage/quality
    - Code maintainability issues

    ## 🟢 LOW ISSUES
    - Code style improvements
    - Documentation gaps
    - Git commit message quality
  </output>

  <check if="you are running unattended — spawned by an orchestrator, with no interactive user to answer">
    <!-- Everything below this point (the fold against prior invariants, the round log, the OUTCOME and ROUNDS lines) is what the orchestrator reads. A blocking question here parks the whole pipeline on a prompt nobody can answer, and the stall detector respawns a fresh agent onto the same question. -->
    <action>Do not ask. Fix every HIGH and MEDIUM finding in the code and tests as option 1 below describes, and file every LOW one as a follow-up item as option 2 describes — LOW only, so nothing you just fixed is also filed as outstanding work. Update the File List when files changed, and record the fixes in the story's Dev Agent Record.</action>
    <action>A HIGH or MEDIUM finding you cannot resolve in this round — it needs a design decision, or real engineering time — is reported as unresolved with the reason, and stays open. Never report it fixed, and never downgrade it to LOW to make it fit: the orchestrator routes an open HIGH or MEDIUM back for a fix round, and that route is the one thing standing between an unfixed finding and an open PR.</action>
    <action>List every HIGH and MEDIUM finding in the report with its own status word, `fixed` or `open`, and its file:line. The orchestrator counts the `open` ones to decide whether the story comes back (dev-tasks step 7); a report that leaves a finding unmarked cannot be counted and will be sent back for the marking.</action>
    <action>Set {{fixed_count}} = the number of HIGH and MEDIUM findings you fixed, and {{action_count}} = the number of LOW follow-ups you filed. Set them here: the two blocks below run only on an interactive answer, so without this the report at step 5 says 0 fixed and 0 filed for a round that did both.</action>
    <action>Say in the report that this split was taken because no user was present, then continue at step 13m — do not fall through to the question below.</action>
  </check>

  <ask if="an interactive user is present">What should I do with these issues?

    1. **Fix them automatically** - I'll update the code and tests
    2. **Create action items** - Add to story Tasks/Subtasks for later
    3. **Show me details** - Deep dive into specific issues

    Choose [1], [2], or specify which issue to examine:</ask>

  <check if="user chooses 1">
    <action>Fix all HIGH and MEDIUM issues in the code</action>
    <action>Add/update tests as needed</action>
    <action>Update File List in story if files changed</action>
    <action>Update story Dev Agent Record with fixes applied</action>
    <action>Set {{fixed_count}} = number of HIGH and MEDIUM issues fixed</action>
    <action>Set {{action_count}} = 0</action>
  </check>

  <check if="user chooses 2">
    <action>Add "Review Follow-ups (AI)" subsection to Tasks/Subtasks</action>
    <action>For each issue this option covers — every issue on the interactive path, LOW only on the unattended path, never one that was just fixed in code: `- [ ] [AI-Review][Severity] Description [file:line]`</action>
    <action>Set {{action_count}} = number of action items created</action>
    <action>Set {{fixed_count}} = 0</action>
  </check>

  <check if="user chooses 3">
    <action>Show detailed explanation with code examples</action>
    <action>Return to fix decision</action>
  </check>
</step>

<step n="13m" goal="13th Man adversarial review (BLOCKING) — runs BEFORE this stage closes">
<critical>This stage does not close on its own say-so. Run this review FIRST; everything below is conditional on its result.</critical>
<critical>It runs whichever option step 4 took, and reviews every finding and fix: fixes made now, and findings deferred as action items or not acted on — a deferred finding still needs a disposition.</critical>
<action>Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md` with stage_id="code-review", artifact_paths=the artifacts this stage produced, and claim=that the change is correct and safe to merge</action>
<critical>Give it the QUESTION, never the answer — hand over what this stage set out to establish, not what it concluded. A gate handed the conclusion confirms it.</critical>
<action>Record YOUR OWN model as DISPATCHER in the report. The pin in .claude/agents/thirteenth-man.md is absolute, but the requirement is RELATIVE — the reviewer must differ from whatever model is running THIS session right now. These come apart silently when this session runs on the pinned model.</action>
<action>Compare DISPATCHER against the MODEL the review reports it ran as. The subagent cannot see your model from inside, so YOU are the only one who can make this comparison.</action>
<check if="DISPATCHER == MODEL, or either is unknown">Stamp the report MODEL: same-model (degraded) and TELL THE USER the gate ran degraded. Never let a subagent assert independence it cannot verify — a degraded review recorded as a normal one retires the concern without earning it.</check>
<check if="verdict is refuted OR any BLOCKER is open">HALT. Do NOT write any status, do NOT mark anything done, and do NOT hand off. Report the blockers, end the report with the single line `OUTCOME: Blocked` — the orchestrator that spawned you branches on that word and has no other way to tell a blocked review from a crashed one — and stop. A blocked round writes no round-log entry and no `ROUNDS:` line; that is correct, and step 5 is not reached.</check>
<check if="verdict is cannot-determine">Do not close on that point — obtain the evidence, or record an explicit, owned, accepted risk before continuing.</check>
<check if="verdict is confirmed or partly-confirmed with no blockers">Proceed ONLY after dispositioning every DISSENT and OBSERVATION, not just the blockers. Each gets one of: fixed (say where), scheduled (name the task or phase), rejected (record the reason), or accepted risk (name an owner and a trigger). An undispositioned finding is an open finding — acting only on blockers is how this gate gets quietly neutered.</check>
<action>Write the returned report to `{output_folder}/planning-artifacts/thirteenth-man/` YOURSELF (the subagent may lack write access) and commit it — it is product knowledge.</action>
</step>

<step n="5" goal="Update story status and sync sprint tracking">
  <action>State this round's OUTCOME as the last-but-one line of your report, in exactly one of these three words, because the orchestrator that spawned you branches on it (dev-tasks step 7) and cannot read it out of prose:
    - `OUTCOME: Approve` — no HIGH or MEDIUM finding remains open and every acceptance criterion is implemented.
    - `OUTCOME: Changes Requested` — a HIGH or MEDIUM finding is still OPEN: one you could not resolve this round, or one you filed rather than fixed. Findings you fixed in this round do not count as remaining — a round that found three HIGH issues and fixed all three is `Approve`. The two are disjoint on that word, OPEN, because the orchestrator branches on it.
    - `OUTCOME: Blocked` — step 13m refuted this review or left a blocker open. Report the blockers, say `OUTCOME: Blocked`, and stop: no status write, no round-log entry, no hand-off.
    The `ROUNDS:` line — its three forms are in *Your Role* at the top of this file, and step 5 repeats the format — is the last line, after it. A report missing either line is incomplete.
  </action>
  <!-- The round log is what the NEXT round reads; without it every round starts blind -->
  <action>Append this round's entry to the story file's `Review Round Log` subsection under Dev Agent Record, creating the subsection when it is absent. One entry, in this shape:
    `- Round <n> (<date>), scope <what you reviewed: the whole story, or the files or change range you were given>: ROUNDS: <none | <n> new | restatement-only>. Invariants filed: <one line per invariant, or "none">. Reviewer model: <your model>.`
    The scope matters because this workflow also runs ad hoc on part of a story (the `CR` command). A later round reads an entry with a narrower scope as covering only that scope — never as evidence the rest was reviewed.
    `<n>` is one more than the highest round number already in the log, or 1 when the log is empty.
  </action>
  <!-- Determine new status based on review outcome -->
  <check if="your spawn prompt says you are reviewing at a story boundary, or names an orchestrator that owns story status">
    <!-- dev-tasks step 7 runs the mandatory adversarial QA gate AFTER this review. A story written `done` here is a story the tracker calls done before that gate has run, and the orchestrator then overwrites it minutes later: two contradicting tracker writes for one boundary pass. The orchestrator owns story status there; you own the report. -->
    <action>Write NO story status, NO sprint-status entry and NO story-level tracker sync in this step. Say in your report what the status WOULD be — `Approve` means the boundary may proceed — and stop after the round-log entry. Skip the rest of this step.</action>
  </check>

  <check if="all HIGH and MEDIUM issues fixed AND all ACs implemented">
    <action>Set {{new_status}} = "done"</action>
    <action>Update story Status field to "done"</action>
  </check>
  <check if="HIGH or MEDIUM issues remain OR ACs not fully implemented">
    <action>Set {{new_status}} = "in-progress"</action>
    <action>Update story Status field to "in-progress"</action>
  </check>
  <action>Save story file</action>

  <!-- Determine sprint tracking status -->
  <check if="{sprint_status} file exists">
    <action>Set {{current_sprint_status}} = "enabled"</action>
  </check>
  <check if="{sprint_status} file does NOT exist">
    <action>Set {{current_sprint_status}} = "no-sprint-tracking"</action>
  </check>

  <!-- Sync sprint-status.yaml when story status changes (only if sprint tracking enabled) -->
  <check if="{{current_sprint_status}} != 'no-sprint-tracking'">
    <action>Load the FULL file: {sprint_status}</action>
    <action>Find development_status key matching {{story_key}}</action>

    <check if="{{new_status}} == 'done'">
      <action>Update development_status[{{story_key}}] = "done"</action>
      <action>Update last_updated field to current date</action>
      <action>Save file, preserving ALL comments and structure</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} done --note "&lt;review verdict, what proved the ACs&gt;"` then `python3 _skad/bmm/lib/op-status.py check {{story_key}}` (dev-tasks R0). This is the transition that matters most: a story finished in the repo and open in the tracker is the disagreement the whole rule exists to prevent. The write logs and continues if OpenProject is unreachable; the `check` is different — the story does not close while it reports a disagreement or an item it could not verify.</action>
      <output>✅ Sprint status synced: {{story_key}} → done</output>
    </check>

    <check if="{{new_status}} == 'in-progress'">
      <action>Update development_status[{{story_key}}] = "in-progress"</action>
      <action>Update last_updated field to current date</action>
      <action>Save file, preserving ALL comments and structure</action>
      <action tag="op-sync">`python3 _skad/bmm/lib/op-status.py story {{story_key}} in-progress --note "&lt;the findings that sent it back&gt;"` — the `done` branch mirrors its write and this one must too, or a story sent back by review keeps whatever the tracker last heard.</action>
      <output>🔄 Sprint status synced: {{story_key}} → in-progress</output>
    </check>

    <check if="story key not found in sprint status">
      <output>⚠️ Story file updated, but sprint-status sync failed: {{story_key}} not found in sprint-status.yaml</output>
    </check>
  </check>

  <check if="{{current_sprint_status}} == 'no-sprint-tracking'">
    <output>ℹ️ Story status updated (no sprint tracking configured)</output>
  </check>

  <output>**✅ Review Complete!**

    **Story Status:** {{new_status}}
    **Issues Fixed:** {{fixed_count}}
    **Action Items Created:** {{action_count}}

    {{#if new_status == "done"}}Code review complete!{{else}}Address the action items and continue development.{{/if}}
  </output>
</step>

</workflow>

