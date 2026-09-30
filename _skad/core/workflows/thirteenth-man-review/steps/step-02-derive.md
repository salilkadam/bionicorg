---
name: 'step-02-derive'
description: 'Answer the de-anchored questions from primary source only, running commands and quoting output'

nextStepFile: '{project-root}/_skad/core/workflows/thirteenth-man-review/steps/step-03-verdict.md'
previousStepFile: '{project-root}/_skad/core/workflows/thirteenth-man-review/steps/step-01-scope.md'
---

# Step 2: Independent Derivation

**Progress: Step 2 of 3** — Next: Verdict and Dissent

## MANDATORY EXECUTION RULES

- 🛑 **NEVER reason from memory about what a codebase contains.** Run the command.
- 🚫 **FORBIDDEN** to cite anything on the UNDER TEST list as evidence.
- 📋 Every factual claim carries the command that produced it and its output.
- ⏱️ Bound every command you run — a hung check is as useless as a skipped one. Keep every tool call under about 9 minutes: the runtime caps a call (Claude Code's Bash tool at 600 s) and silently backgrounds a longer timeout, which parks you. Run anything longer detached, `nohup sh -c '( <cmd> ) > <log> 2>&1; echo EXIT=$? >> <log>' >/dev/null 2>&1 & echo $! > <log>.pid` with an absolute log path unique to that command, and poll the log for `EXIT=` in foreground slices, for at most a stated number of slices (the expected duration plus a margin). When that maximum is reached or the wrapper is dead (`kill -0` on the pid fails), re-read the log once more; only if it still has no `EXIT=` line is it a failure — record it, never "still running". Never end your turn to wait for a background job — nothing will wake you.
- ✅ Speak in `{communication_language}`.

## YOUR TASK

Answer each question from Step 01, in order, from SOURCE only.

### 1. Run the disconfirmer first

Start with the disconfirming question. If the claim is false, this is where it shows,
and finding it first prevents a page of confirmatory work you would then have to
discard.

### 2. For each question, produce evidence

For every question, record:

```
Q<n>: <the question>
CMD:  <the exact command>
OUT:  <the output, excerpted honestly — including the parts that do not help>
READ: <what this does and does not establish>
```

**Excerpting honestly** means: if the output is 200 lines and 3 contradict your
emerging view, those 3 are in the excerpt.

### 3. Apply the three-question discipline to every absence

For anything claimed absent, run **three separate checks** and report each:

1. **Exists?** — search the source tree. Not just filenames: the symbol, the config
   key, the CRD, the rule.
2. **Wired?** — find the importers and call sites. A file that nothing imports is not
   wired. A handler no route reaches is not wired.
3. **On by default?** — chart values, flag defaults, environment gates, feature
   toggles, licence gates.

Report **which of the three fails**. "Exists but off by default" and "not built" are
different findings with different costs, and conflating them misleads planning as
badly as missing the gap entirely.

### 4. Recompute every count

Never carry a number forward from the artifact. Count it yourself, with a command, and
show the command. If your count differs from the artifact's, that is a finding.

### 5. Justify every negative result

A search returning nothing is evidence **only if it would have matched had the thing
existed**. For each empty result, state why the pattern is sufficient — and where you
are unsure, widen the pattern and say you did.

Consider: different naming conventions, generated code, vendored dependencies,
non-obvious file extensions, and the thing being configured rather than coded.

An absence claim is only as wide as the search behind it. Before reporting "no test
for X" or "not wired", search the **whole package or module**, not just the file
the claim came from.

### 6. Prove the gates

Where the stage relies on a check, test, guard or gate: **a gate that has never failed
has not been tested.** Where you can, inject a violation and confirm the gate catches
it. A guard that passes when the defect is reintroduced is worse than no guard,
because it retires the concern.

Run the check **in the mode it really runs in** — for dev-tasks Verification
Commands, each line individually with `!` semantics, never one `set -e` block. **If a
planted defect does not make the check fail, the plant or the check is wrong**, and
neither can be trusted until one of them fails.

### 7. Verify external claims at the vendor

For any claim about a third-party system, cite the **vendor's own documentation or the
system's own behaviour**. A blog post summarising the docs is not the docs, and is
frequently a version behind.

### 8. Record what you could not check

Keep a running list. Access you did not have, systems you could not reach, claims that
are unfalsifiable as stated, areas you ran out of budget for.

**This list going to the report is mandatory. Silence here is a failure**, because an
unchecked area silently reads as a checked one.

---

## OUTPUT OF THIS STEP

- The `Q/CMD/OUT/READ` block for every question
- The three-question result for every absence claim
- Recomputed counts alongside the artifact's stated counts
- The running "could not check" list

## SUCCESS METRICS

✅ Every claim backed by a command and its real output
✅ Disconfirmer run first
✅ Absence claims resolved into exists / wired / on-by-default
✅ Counts recomputed, not repeated
✅ Empty results justified
✅ Gates tested by injection where possible
✅ "Could not check" list maintained honestly

## FAILURE MODES

❌ Asserting what the code does without running anything
❌ Citing a planning artifact as evidence
❌ Excerpting only the output that supports the emerging view
❌ Treating an empty grep as proof without justifying the pattern
❌ Repeating the artifact's own count
❌ Trusting a gate because it is green
❌ Leaving unchecked areas unmentioned

## NEXT STEP

Read fully and follow `{nextStepFile}`.
