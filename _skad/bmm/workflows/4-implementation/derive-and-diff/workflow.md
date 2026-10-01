# Derive and Diff — expectations against reality

**Goal:** Find the requirements nobody wrote down.

**Your Role:** Orchestrator of three separate jobs done by three different models. You do not
perform all three yourself, and the reason is the whole method.

---

## Why this exists

An **audit** asks whether what was built matches what was claimed. It finds wrong answers,
and it is structurally incapable of finding a requirement nobody ever wrote. Every review
gate in this methodology is an audit. This workflow is the other half: derive from the goal
what *should* be true, map what actually exists, and diff them. The gap is the finding set.

**Run it when the cost of being wrong has grown**: at an epic boundary, before a release,
after a burst of change to the methodology or architecture, or whenever someone notices that
review rounds keep finding small things while something large feels off.

## The three jobs, and why they are separated

| Phase | Job | Model | May see |
|---|---|---|---|
| 1 | **Expectations** | any | The goal, the owner's own words, the product's purpose |
| 2 | **Reader** | **different from 1** | The sources only |
| 3 | **Triage** | **different from 1 and 2** | Both outputs, plus the sources |

Two rules carry the whole method, and a hurried run drops both:

1. **The reader never sees the expectations.** A reader told what to look for finds exactly
   that, and the diff becomes a formality. Run phases 1 and 2 concurrently if you like —
   they do not depend on each other — but never in that order with sight between them.
2. **The expectations author must not be the only reader of their own work.** Whoever wrote
   the thing under test knows what they *intended* and will read intent into text that does
   not carry it. That is why phase 2 is a different model, and why phase 3 is a third.

---

## Step 1 — Expectations

<step n="1" goal="Derive what should be true, from the goal and not from the code">

<critical>Write these BEFORE reading the implementation, or from a session that has not been
building it. Expectations written afterwards quietly become a description of what exists,
and the diff then has nothing to find.</critical>

<action>Derive, from the product's stated goals and the owner's own words, what must be true
for the system to do what it is for. Each expectation is a testable statement, not a value.
"The system is reliable" is not one; "a code path that can fail can report that it failed" is.</action>

<action>Mark every expectation with its PROVENANCE, and keep the marks in the artifact:
  - **[OWNER]** — the owner's own words, quoted. Authoritative.
  - **[DERIVED]** — follows from an [OWNER] statement but was never said. The owner ratifies
    or strikes it; an unmarked [DERIVED] item is NOT ratified, and triage reports it as such
    rather than assuming assent.
  - **[SUSPECT]** — describes machinery that already exists. A claim under test, never an
    expectation. If the owner does not recognise it as a goal, it is over-build, and removing
    it is work like any other.
</action>

<action>List the gaps already known, before the review starts. A review credited with
rediscovering what everyone knew has not earned its cost, and this tells it where not to
spend.</action>

<action>Name the EXIT CONDITION here, in the artifact: this review is done when every
ratified expectation carries met / partially met / not met / withdrawn, and every gap has a
disposition — not when the models run out of things to say.</action>

<action>The owner ratifies before triage. Ratification does not block phase 2, which is
forbidden this document anyway.</action>
</step>

## Step 2 — The reader

<step n="2" goal="Map what exists, cold, with a different model">

<critical>Pin a model different from the one that wrote the expectations. Give it the sources
and NOT the expectations, NOT the planning artifacts, NOT the commit history, NOT any
retrospective. Those are what people said about the system; it is describing the system.</critical>

<action>Ask it to map, in its own words and quoting file:line throughout: what runs and in
what order; what each stage produces and who reads each field later; every place the work can
refuse to continue, what each stop halts and who is expected to act; at which levels criteria
are written and at which they are verified, and what evidence a verification requires; how
the system knows one item must wait for another; what runs in parallel, shown by where it is
implemented rather than where it is permitted; which checks can actually fail, with the input
that would fail each; and how much a single unit of work has to carry.</action>

<action>Require it to distinguish "could not determine" from "not present" — those are
different answers and must not read the same — and to report both sides where the source
contradicts itself rather than resolving it.</action>
</step>

## Step 3 — Triage and plan

<step n="3" goal="Diff, classify, and produce a plan with a third model">

<action>Pin a third model. Give it the ratified expectations, the reader's map, and access to
the sources. Neither document is authority over the source: where either makes a claim that
changes the plan, it verifies that claim itself and says which it checked.</action>

<action>Produce the diff: one row per expectation — met / partially met / not met / cannot
determine — with its evidence. Counts are computed, never stated.</action>

<action>Classify every gap three ways, separately, because the answers have different shapes:
**does it exist**, **is it wired**, **is it on by default**. "Not on" is a configuration
change, "not wired" is a day, "not built" is an epic.</action>

<action>Name what to REMOVE. The map will describe machinery no ratified expectation calls
for. Say what it costs per unit of work to keep it. A methodology that only grows stops being
followable, which is itself an expectation.</action>

<action>Order the plan by expected value per unit of effort, not by severity, and say plainly
which items are not worth doing. For each: what changes, where, what would prove it worked,
and what it costs to run every time thereafter.</action>

<action>Where the two input documents disagree, that disagreement is itself a finding.
Report it rather than picking a side.</action>
</step>

## Step 4 — Disposition

<step n="4" goal="Close the loop, or the review was an opinion">

<action>Every gap gets a recorded disposition — fixed (say where), scheduled (name the task
or phase; "later" is not a disposition), rejected (record the reason, so the disagreement is
visible rather than re-litigated), or accepted risk (name an owner and a trigger). An
undispositioned finding is an open finding.</action>

<action>Commit the expectations, the map, the diff and the dispositions together. They are
product knowledge, and the next run of this workflow starts by diffing against them.</action>
</step>
