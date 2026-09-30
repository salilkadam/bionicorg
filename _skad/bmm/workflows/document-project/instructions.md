# Document Project Workflow Router

<critical>Communicate all responses in {communication_language}</critical>

<workflow>

<critical>This router determines workflow mode and delegates to specialized sub-workflows</critical>

<step n="1" goal="Check for ability to resume and determine workflow mode">
<action>Check for existing state file at: {project_knowledge}/project-scan-report.json</action>

<check if="project-scan-report.json exists">
  <action>Read state file and extract: timestamps, mode, scan_level, current_step, completed_steps, project_classification</action>
  <action>Extract cached project_type_id(s) from state file if present</action>
  <action>Calculate age of state file (current time - last_updated)</action>

<ask>I found an in-progress workflow state from {{last_updated}}.

    **Current Progress:**

    - Mode: {{mode}}
    - Scan Level: {{scan_level}}
    - Completed Steps: {{completed_steps_count}}/{{total_steps}}
    - Last Step: {{current_step}}
    - Project Type(s): {{cached_project_types}}

    Would you like to:

    1. **Resume from where we left off** - Continue from step {{current_step}}
    2. **Start fresh** - Archive old state and begin new scan
    3. **Cancel** - Exit without changes

    Your choice [1/2/3]:
</ask>

  <check if="user selects 1">
    <action>Set resume_mode = true</action>
    <action>Set workflow_mode = {{mode}}</action>
    <action>Load findings summaries from state file</action>
    <action>Load cached project_type_id(s) from state file</action>

    <critical>CONDITIONAL CSV LOADING FOR RESUME:</critical>
    <action>For each cached project_type_id, load ONLY the corresponding row from: {documentation_requirements_csv}</action>
    <action>Skip loading project-types.csv and architecture_registry.csv (not needed on resume)</action>
    <action>Store loaded doc requirements for use in remaining steps</action>

    <action>Display: "Resuming {{workflow_mode}} from {{current_step}} with cached project type(s): {{cached_project_types}}"</action>

    <check if="workflow_mode == deep_dive">
      <action>Read fully and follow: {installed_path}/workflows/deep-dive-workflow.md with resume context</action>
    </check>

    <check if="workflow_mode == initial_scan OR workflow_mode == full_rescan">
      <action>Read fully and follow: {installed_path}/workflows/full-scan-workflow.md with resume context</action>
    </check>

  </check>

  <check if="user selects 2">
    <action>Create archive directory: {project_knowledge}/.archive/</action>
    <action>Move old state file to: {project_knowledge}/.archive/project-scan-report-{{timestamp}}.json</action>
    <action>Set resume_mode = false</action>
    <action>Continue to Step 3</action>
  </check>

  <check if="user selects 3">
    <action>Display: "Exiting workflow without changes."</action>
    <action>Exit workflow</action>
  </check>

  <check if="state file age >= 24 hours">
    <action>Display: "Found old state file (>24 hours). Starting fresh scan."</action>
    <action>Archive old state file to: {project_knowledge}/.archive/project-scan-report-{{timestamp}}.json</action>
    <action>Set resume_mode = false</action>
    <action>Continue to Step 3</action>
  </check>
</check>

</step>

<step n="3" goal="Check for existing documentation and determine workflow mode" if="resume_mode == false">
<action>Check if {project_knowledge}/index.md exists</action>

<check if="index.md exists">
  <action>Read existing index.md to extract metadata (date, project structure, parts count)</action>
  <action>Store as {{existing_doc_date}}, {{existing_structure}}</action>

<ask>I found existing documentation generated on {{existing_doc_date}}.

What would you like to do?

1. **Re-scan entire project** - Update all documentation with latest changes
2. **Deep-dive into specific area** - Generate detailed documentation for a particular feature/module/folder
3. **Cancel** - Keep existing documentation as-is

Your choice [1/2/3]:
</ask>

  <check if="user selects 1">
    <action>Set workflow_mode = "full_rescan"</action>
    <action>Display: "Starting full project rescan..."</action>
    <action>Read fully and follow: {installed_path}/workflows/full-scan-workflow.md</action>
    <action>After sub-workflow completes, continue to Step 13m</action>
  </check>

  <check if="user selects 2">
    <action>Set workflow_mode = "deep_dive"</action>
    <action>Set scan_level = "exhaustive"</action>
    <action>Display: "Starting deep-dive documentation mode..."</action>
    <action>Read fully and follow: {installed_path}/workflows/deep-dive-workflow.md</action>
    <action>After sub-workflow completes, continue to Step 13m</action>
  </check>

  <check if="user selects 3">
    <action>Display message: "Keeping existing documentation. Exiting workflow."</action>
    <action>Exit workflow</action>
  </check>
</check>

<check if="index.md does not exist">
  <action>Set workflow_mode = "initial_scan"</action>
  <action>Display: "No existing documentation found. Starting initial project scan..."</action>
  <action>Read fully and follow: {installed_path}/workflows/full-scan-workflow.md</action>
  <action>After sub-workflow completes, continue to Step 13m</action>
</check>

</step>

<step n="13m" goal="13th Man adversarial review (ADVISORY) — runs BEFORE this stage closes">
<critical>This stage does not close on its own say-so. Run this review FIRST; everything below is conditional on its result.</critical>
<action>Read fully and follow: `{project-root}/_skad/core/workflows/thirteenth-man-review/workflow.md` with stage_id="project-docs", artifact_paths=the artifacts this stage produced, and claim=that the generated documentation matches what the repository actually contains</action>
<critical>Give it the QUESTION, never the answer — hand over what this stage set out to establish, not what it concluded. A gate handed the conclusion confirms it.</critical>
<action>Record YOUR OWN model as DISPATCHER in the report. The pin in .claude/agents/thirteenth-man.md is absolute, but the requirement is RELATIVE — the reviewer must differ from whatever model is running THIS session right now. These come apart silently when this session runs on the pinned model.</action>
<action>Compare DISPATCHER against the MODEL the review reports it ran as. The subagent cannot see your model from inside, so YOU are the only one who can make this comparison.</action>
<check if="DISPATCHER == MODEL, or either is unknown">Stamp the report MODEL: same-model (degraded) and TELL THE USER the gate ran degraded. Never let a subagent assert independence it cannot verify — a degraded review recorded as a normal one retires the concern without earning it.</check>
<check if="verdict is refuted OR any BLOCKER is open">Record the findings in this stage's output before continuing.</check>
<check if="verdict is cannot-determine">Do not close on that point — obtain the evidence, or record an explicit, owned, accepted risk before continuing.</check>
<check if="verdict is confirmed or partly-confirmed with no blockers">Proceed ONLY after dispositioning every DISSENT and OBSERVATION, not just the blockers. Each gets one of: fixed (say where), scheduled (name the task or phase), rejected (record the reason), or accepted risk (name an owner and a trigger). An undispositioned finding is an open finding — acting only on blockers is how this gate gets quietly neutered.</check>
<action>Write the returned report to `{output_folder}/planning-artifacts/thirteenth-man/` YOURSELF (the subagent may lack write access) and commit it — it is product knowledge.</action>
</step>

</workflow>
