---
stepsCompleted: []
inputDocuments: []
---

# {{project_name}} - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for {{project_name}}, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

{{fr_list}}

### NonFunctional Requirements

{{nfr_list}}

### Additional Requirements

{{additional_requirements}}

### FR Coverage Map

{{requirements_coverage_map}}

## GOAL

<!-- One sentence: what the product must let someone do, from the product brief in `{planning_artifacts}/`
     (`create-product-brief` writes `product-brief-<project>-<date>.md`, so match the pattern). This is the topmost rung — it goes into the INITIATIVE work package's description at
     sync, with the PRD brief attached. Written so someone who was not there can say whether it is
     met; this is the one level where vagueness cannot be caught from below. -->

{{goal}}

## Capabilities → GOAL

<!-- The rung between the GOAL and the epics. Each capability is what the user GETS, not what gets
     built, and the Epics column is the downward coverage check: a capability with no epic is the
     product not being built. -->

| Capability | What the user gets | Epics |
|---|---|---|
{{capabilities_to_goal}}

## Epic → Capability

<!-- The upward trace, one entry per epic. This is the direction nobody checks, because an epic
     that serves no capability looks like diligence rather than scope creep — and it is the most
     expensive defect in the chain, because it is fully built before anyone notices. -->

{{epic_to_capability}}

**Epics serving no capability:** {{orphan_epics}}

<!-- `none` is written out. "Nothing to report" and "nobody checked" must not look the same. -->

## Epic List

{{epics_list}}

<!-- Repeat for each epic in epics_list (N = 1, 2, 3...) -->

## Epic {{N}}: {{epic_title_N}}

**Goal:** {{epic_goal_N}}

**Depends on:** {{epic_dependencies_N}}

<!-- `Blocked on:` is the older spelling of this field and is still read wherever it appears;
     its entries are all hard by definition. New artifacts use `Depends on:`. -->

<!-- One line per dependency: `hard: Epic {{K}} — <what this epic needs from it>` or `soft: …`.
     HARD means this epic cannot be built correctly until that one's acceptance gate has PASSED —
     an epic that sends email templates has a hard dependency on the epic that stands up the mail
     system. A hard dependency must be ordered BEFORE its dependent here and linked in the tracker.
     SOFT means it would be convenient, not required. `none` is a valid and common answer; write it
     rather than leaving the field empty, so "no dependencies" and "nobody considered it" look different. -->

**Acceptance Criteria:**

<!-- The EPIC's own criteria, not the union of its stories'. Each one is a sentence someone can
     verify against the running system at the end of the epic, and each names what would prove it.
     These are what the epic acceptance gate rolls its stories up to, so a criterion no story
     discharges is an orphan the gate will fail on. -->

{{epic_acceptance_criteria_N}}

<!-- OPTIONAL FEATURE LEVEL. Use it when an epic delivers several user-visible capabilities that are
     verified separately; skip it entirely when the epic's stories roll straight up. When present,
     story criteria discharge the feature's, and the features' discharge the epic's. -->

### Feature {{N}}.{{F}}: {{feature_title_N_F}}

**Goal:** {{feature_goal_N_F}}

**Depends on:** {{feature_dependencies_N_F}}

**Acceptance Criteria:**

{{feature_acceptance_criteria_N_F}}

<!-- Repeat for each story (M = 1, 2, 3...) within epic N (under its feature, where features are used) -->

### Story {{N}}.{{M}}: {{story_title_N_M}}

As a {{user_type}},
I want {{capability}},
So that {{value_benefit}}.

**Depends on:** {{story_dependencies_N_M}}

<!-- Same rules as the epic's field: `hard:`/`soft:` per line, `none` written out. A hard dependency
     on a story in ANOTHER epic implies that epic is a hard dependency of this one too — say both. -->

**Acceptance Criteria:**

<!-- for each AC on this story -->

**Given** {{precondition}}
**When** {{action}}
**Then** {{expected_outcome}}
**And** {{additional_criteria}}

<!-- End story repeat -->
