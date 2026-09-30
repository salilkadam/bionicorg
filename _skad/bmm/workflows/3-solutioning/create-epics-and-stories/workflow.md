---
name: create-epics-and-stories
description: 'Break requirements into epics and user stories. Use when the user says "create the epics and stories list"'
---

# Create Epics and Stories

**Goal:** Transform PRD requirements and Architecture decisions into comprehensive stories organized by user value, creating detailed, actionable stories with complete acceptance criteria for development teams.

**Your Role:** In addition to your name, communication_style, and persona, you are also a product strategist and technical specifications writer collaborating with a product owner. This is a partnership, not a client-vendor relationship. You bring expertise in requirements decomposition, technical implementation context, and acceptance criteria writing, while the user brings their product vision, user needs, and business requirements. Work together as equals.

## MANDATORY PROCESS RULES (apply to every epic/story produced)

1. **Traceability (R3):** Open the epics with a GOAL, a Capabilities→GOAL map, and an Epic→Capability map; tag each epic with its capability. Every story belongs to an epic; flag any orphan or any two components that should connect but don't.
2. **No mock integration tests (R1):** Every integration/E2E acceptance criterion names the REAL infrastructure it hits + an infra-precheck. Never write an AC that an in-memory fake / in-process stub / monkeypatched service could satisfy.
3. **Infrastructure Epic if needed (R2):** If any story needs infrastructure that isn't wired, create (or add to) an **Infrastructure Epic** and mark the dependent story blocked on it — do not let it be satisfied by a mock.
4. **Per-epic QA adversarial story (R4/R5):** Every epic ENDS with a QA story whose acceptance is: the adversarial QA role drives the REAL application (browser) on real infrastructure, audits the epic's integration tests for mocks (flagging any as defects), and tries to break the user journey. The epic is not done until this passes.
5. **Crisp criteria at every level (R6):** Every EPIC, every FEATURE where the level is used, and every STORY carries its own **Goal** and its own **Acceptance Criteria** — verifiable against the running system, each naming what would prove it. An epic's criteria are the epic's own, never the union of its stories': the epic acceptance gate rolls stories up to them, and a criterion no child discharges is an orphan that gate fails on. A level with a goal but no criteria cannot be validated later, and "we will know it when we see it" is the thing this rule exists to stop.
6. **Hard dependencies are declared and ordered (R7):** Every epic, feature and story carries a `Depends on:` field, one line per dependency, marked `hard:` or `soft:`, with `none` written out rather than left blank — absence and "nobody considered it" must not look the same. HARD means the dependent cannot be built correctly until the dependency's acceptance gate has PASSED: an epic that builds email templates and verifies delivery has a hard dependency on the epic that stands up the mail system. Order the artifact so every hard dependency PRECEDES its dependent, at every level; a hard dependency pointing forward is a defect in the breakdown, not a note for later. A story with a hard dependency on a story in another epic makes that epic a hard dependency of this one — state both. These fields become tracker links at sync time, and dev-tasks refuses to start an item whose hard dependency is unmet (R19).
7. **The GOAL is the root, and coverage is checked BOTH ways (R8):** the epics hang from the
   GOAL and its capabilities, taken from the product brief that `create-product-brief`
   writes to `{planning_artifacts}/` as `product-brief-<project>-<date>.md`, and from the PRD, and
   held in an **Initiative** work package with the PRD brief attached. This is the same chain
   R3 names — GOAL → Capabilities → Epics — and there is only one vocabulary for it. Check the mapping in both
   directions and report each separately, because they fail differently:
   **Downward** — every capability is delivered by at least one epic. An uncovered goal is
   the product not being built, and it is invisible if you only read the epics.
   **Upward** — every epic names at least one capability it serves. An epic serving none
   is work nobody asked for; this is the direction nobody checks, because scope creep looks
   like diligence, and it is the most expensive defect in the chain since it is fully built
   before anyone notices.
   Record the mapping — which epic serves which capability — rather than leaving it to be
   re-derived later by reading both and forming an impression. The same two-way check applies
   at every level below (epic→feature→story). It is a DIFFERENT axis from the epic
   acceptance gate in dev-tasks, which rolls story and feature acceptance CRITERIA up to
   the epic's criteria — that gate does not read this goal↔epic mapping, and saying
   otherwise would claim a connection that does not exist.
8. Write these into both the epics/stories artifact and the sprint-status artifact (rows incl. the per-epic QA story and the capability/GOAL tags).

---

## WORKFLOW ARCHITECTURE

This uses **step-file architecture** for disciplined execution:

### Core Principles

- **Micro-file Design**: Each step of the overall goal is a self contained instruction file that you will adhere too 1 file as directed at a time
- **Just-In-Time Loading**: Only 1 current step file will be loaded and followed to completion - never load future step files until told to do so
- **Sequential Enforcement**: Sequence within the step files must be completed in order, no skipping or optimization allowed
- **State Tracking**: Document progress in output file frontmatter using `stepsCompleted` array when a workflow produces a document
- **Append-Only Building**: Build documents by appending content as directed to the output file

### Step Processing Rules

1. **READ COMPLETELY**: Always read the entire step file before taking any action
2. **FOLLOW SEQUENCE**: Execute all numbered sections in order, never deviate
3. **WAIT FOR INPUT**: If a menu is presented, halt and wait for user selection
4. **CHECK CONTINUATION**: If the step has a menu with Continue as an option, only proceed to next step when user selects 'C' (Continue)
5. **SAVE STATE**: Update `stepsCompleted` in frontmatter before loading next step
6. **LOAD NEXT**: When directed, read fully and follow the next step file

### Critical Rules (NO EXCEPTIONS)

- 🛑 **NEVER** load multiple step files simultaneously
- 📖 **ALWAYS** read entire step file before execution
- 🚫 **NEVER** skip steps or optimize the sequence
- 💾 **ALWAYS** update frontmatter of output files when writing the final output for a specific step
- 🎯 **ALWAYS** follow the exact instructions in the step file
- ⏸️ **ALWAYS** halt at menus and wait for user input
- 📋 **NEVER** create mental todo lists from future steps

---

## INITIALIZATION SEQUENCE

### 1. Configuration Loading

Load and read full config from {project-root}/\_skad/bmm/config.yaml and resolve:

- `project_name`, `output_folder`, `planning_artifacts`, `user_name`, `communication_language`, `document_output_language`
- ✅ YOU MUST ALWAYS SPEAK OUTPUT In your Agent communication style with the config `{communication_language}`

### 2. First Step EXECUTION

Read fully and follow: `{project-root}/_skad/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-01-validate-prerequisites.md` to begin the workflow.
