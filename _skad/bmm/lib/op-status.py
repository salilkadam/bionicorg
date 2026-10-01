#!/usr/bin/env python3
"""op-status — the one way SKAD moves work in OpenProject, and checks it agreed.

Why this exists. Keeping the tracker current by hand — someone remembering to run
`op_call update_work_package_status` after each task — works and is not a mechanism.
The tracker is part of "done" exactly as the commit is: a story finished in the repo
and stale in the tracker is a story two people will disagree about, and the
disagreement surfaces at the worst moment. So the transition belongs in the workflow,
mechanically, and the agreement belongs in a check that can fail.

Commands (all take the story key as the sprint-status key, e.g.
`1-2-a-reproducible-cluster-with-the-chart-installed-from-the-working-tree`):

  task      <story-key> <task-file-stem> <phase> [--note TEXT]
            phase: in-dev | in-review | in-test | passed | failed
  story     <story-key> <state> [--note TEXT]
            state: in-progress | review | done | blocked
  epic      <n> <state> [--note TEXT]
  bug       <story-key> "<subject>" [--body-file PATH] [--note TEXT]
  bug-close <bug-wp-id> --note TEXT   close a Bug, naming the fix and what re-verified it
  bootstrap <story-key>          create a Task work package per task file, attach it
  check     [story-key]          tracker vs sprint-status.yaml vs task files

`check` exits 0 when it compared at least one work package and all agreed, 1 on any
disagreement OR any work package it could not read, and 2 when there was nothing to
compare. Three codes because there are three facts: agreement, disagreement, and
silence — and silence has to be distinguishable from a pass by a caller that sees
only the exit code.

`check` is the point of the tool: it makes the sync verifiable instead of trusted.
It resolves the expected status through the SAME `status_map` the writers use, so it
verifies exactly what a write claims to have done rather than a second, hand-kept
table of status names. It is what a story boundary runs, and what a repo's pre-commit
hook should run when sprint-status.yaml is staged.

Nothing here reads or prints a credential; the MCP bridge needs none on argv.
"""
import argparse
import base64
import json
import os
import re
import subprocess
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("op-status: PyYAML missing. Tracker NOT synced.\n")
    sys.exit(1)

def _repo_root():
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        sys.stderr.write("op-status: not inside a git repository, so there is no project "
                         "root to resolve _skad/ against. Run this from the project. "
                         "Tracker NOT synced.\n")
        sys.exit(1)
    return r.stdout.strip()


ROOT = _repo_root()
ENV = os.path.join(ROOT, "_skad/bmm/lib/openproject-env.sh")
MAP = os.path.join(ROOT, "_skad/bmm/openproject-map.yaml")
CONFIG = os.path.join(ROOT, "_skad/bmm/config.yaml")


def load_config():
    """The module config decides where implementation artifacts live, not this file."""
    try:
        with open(CONFIG) as fh:
            return yaml.safe_load(fh) or {}
    except FileNotFoundError:
        return {}


CFG = load_config()
# config.yaml writes these as "./_skad-output/…"; normpath against ROOT handles the
# leading "./" without eating a leading dot from a genuinely dot-prefixed folder.
IMPL = os.path.normpath(os.path.join(ROOT, CFG.get("implementation_artifacts")
                                     or os.path.join(CFG.get("output_folder") or "_skad-output",
                                                     "implementation-artifacts")))
SPRINT = os.path.join(IMPL, "sprint-status.yaml")
TASKS = os.path.join(IMPL, "tasks")

# The task file's own Status line carries the finer grain (in-dev / in-review /
# in-test) and the note records which phase it was; the tracker carries the coarse
# state. Absence and failure never share a representation: a failed task goes to
# the tracker's failed state, never silently stays open.
#
# `in-test` maps to in_progress, not review, because **the tracker's workflow is
# per type and the Task type does not permit it.** Measured on OpenProject 2026-09-12:
# from "In progress" a Task may go only to Closed, Rejected or On hold — "Developed",
# "In testing" and "Tested" are all refused with a 422 for this role. A Story from
# the same state may go to any of them. A map that assumes otherwise fails at the
# moment someone finishes testing, which is the worst time to discover it.
PHASE_STATE = {
    "in-dev": "in_progress",
    "in-review": "in_progress",
    "in-test": "in_progress",
    "passed": "done",
    "failed": "failed",
}
STORY_STATE = {"in-progress": "in_progress", "review": "review", "done": "done", "blocked": "failed"}


def load_map():
    try:
        with open(MAP) as fh:
            return yaml.safe_load(fh) or {}
    except FileNotFoundError:
        raise RuntimeError(
            f"op-status: no {MAP}. This project has not been synced to OpenProject yet — "
            "run create-epics-and-stories step-05 first. Tracker NOT synced.")
    except yaml.YAMLError as ex:
        raise RuntimeError(f"op-status: {MAP} is not valid YAML ({ex}). Tracker NOT synced.")


def project_id(mp):
    pid = mp.get("openproject_id") or CFG.get("openproject_id")
    if not pid:
        raise RuntimeError("op-status: no `openproject_id` in openproject-map.yaml or config.yaml. "
                           "Tracker NOT synced.")
    return int(pid)


def type_id(mp, name, default=None):
    tid = (mp.get("type_ids") or {}).get(name, default)
    if not tid:
        raise RuntimeError(f"op-status: no type id for {name!r} in openproject-map.yaml. Tracker NOT synced.")
    return int(tid)


def op(tool, args, call_id=1):
    """Call one MCP tool through openproject-env.sh; raise with the reason on failure."""
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
        fh.write(json.dumps(args))
        argf = fh.name
    # The payload goes through a file: a base64 attachment on argv has already hit
    # OSError "Argument list too long" once.
    cmd = f'source "{ENV}" && op_call "$1" "$(cat "$2")" "$3"'
    try:
        r = subprocess.run(["bash", "-c", cmd, "_", tool, argf, str(call_id)],
                           capture_output=True, text=True, timeout=180)
    finally:
        os.unlink(argf)
    if r.returncode != 0:
        raise RuntimeError(f"op-status: {tool} failed — {r.stderr.strip()[:400]}. Tracker NOT synced.")
    return json.loads(r.stdout) if r.stdout.strip() else {}


def status_id(mp, name):
    sid = (mp.get("status_map") or {}).get(name)
    if not sid:
        raise RuntimeError(f"op-status: no status id for {name!r} in the map. Tracker NOT synced.")
    return int(sid)


def wp_for(mp, key):
    entry = (mp.get("work_packages") or {}).get(key)
    if not isinstance(entry, dict) or not entry.get("wp_id"):
        raise RuntimeError(f"op-status: {key!r} has no work package in the map. Run `bootstrap` first.")
    return int(entry["wp_id"])


def set_status(mp, wp_id, state_name, note):
    want = status_id(mp, state_name)
    try:
        res = op("update_work_package_status",
                 {"work_package_id": wp_id, "status_id": want,
                  **({"comment": note} if note else {})}, 900)
    except RuntimeError as ex:
        if "no valid transition exists" not in str(ex):
            raise
        # The tracker's workflow is per work-package TYPE and per role. A refusal
        # here is a statement about the workflow, not about this work package, and
        # saying so is the difference between a fixable report and a mystery.
        try:
            cur, cur_title = live_status(wp_id)
            where = f"#{wp_id} is currently status {cur} ({cur_title})"
        except RuntimeError:
            where = f"#{wp_id}'s current status could not be read"
        raise RuntimeError(
            f"op-status: the tracker refuses the move to status {want} ({state_name}). "
            f"{where}. OpenProject workflows are defined per work-package type and per "
            f"role, so a transition that is legal for a Story can be illegal for a Task. "
            f"Fix the mapping in PHASE_STATE/STORY_STATE, or the workflow in OpenProject — "
            f"do not retry. Tracker NOT synced.")
    got = (res.get("work_package") or {}).get("status") or "?"
    print(f"#{wp_id} -> {got}")
    return got


def task_key(story_key, stem):
    return f"{story_key}/{stem}"


def cmd_task(a, mp):
    state = PHASE_STATE.get(a.phase)
    if not state:
        raise RuntimeError(f"op-status: unknown phase {a.phase!r} (in-dev|in-review|in-test|passed|failed)")
    note = a.note or f"Phase {a.phase} (SKAD dev-tasks, {a.story_key})."
    set_status(mp, wp_for(mp, task_key(a.story_key, a.stem)), state, note)


def cmd_story(a, mp):
    state = STORY_STATE.get(a.state)
    if not state:
        raise RuntimeError(f"op-status: unknown story state {a.state!r}")
    set_status(mp, wp_for(mp, a.story_key), state, a.note or f"Story {a.state} (SKAD).")


def cmd_epic(a, mp):
    state = STORY_STATE.get(a.state)
    if not state:
        raise RuntimeError(f"op-status: unknown epic state {a.state!r}")
    set_status(mp, wp_for(mp, f"epic-{a.n}"), state, a.note or f"Epic {a.state} (SKAD).")


def cmd_bug(a, mp):
    """File a Bug under its story, and record it so it can be closed later.

    A bug the tool can file but never close is half a mechanism: the run that
    fixes it would have to reach past this file to say so, which is exactly the
    hand-maintained step R0 exists to remove.
    """
    parent = wp_for(mp, a.story_key)
    body = open(a.body_file).read() if a.body_file else (a.note or "")
    res = op("create_work_package",
             {"project_id": project_id(mp), "subject": a.subject[:255],
              "type_id": type_id(mp, "bug"), "description": body}, 901)
    wp = int(res.get("id") or (res.get("work_package") or {}).get("id"))
    mp.setdefault("work_packages", {})[f"{a.story_key}/bug-{wp}"] = {
        "wp_id": wp, "parent_wp_id": parent, "title": a.subject[:255]}
    save_map(mp)
    op("set_work_package_parent", {"work_package_id": wp, "parent_id": parent}, 902)
    print(f"bug #{wp} filed under #{parent}")


def cmd_bugclose(a, mp):
    """Close a Bug with a note naming the fix and the re-verification.

    The note is not decoration. A bug closed with no account of what fixed it
    and what proved the fix is a bug that will be reopened by whoever next hits
    it, with the diagnosis started from scratch.
    """
    if not a.note:
        raise RuntimeError("op-status: closing a bug requires --note naming the fix and "
                           "what re-verified it. Tracker NOT synced.")
    set_status(mp, int(a.wp_id), "done", a.note)


def tracker_inventory(pid):
    """Every work package in the project, {subject: id}, read from the tracker.

    The map records only what SKAD itself created. It cannot see a work package
    made by hand, by a teammate, or by an earlier run whose map was lost — and it
    is the file most likely to be missing exactly when it matters. So the
    duplicate check reads the system of record, never our own record of it.

    Raises on failure. "Could not look" must never read as "found nothing": the
    caller refuses to create rather than risking a second work package for one
    task, which splits the history and leaves status sync updating whichever one
    the map happens to point at.
    """
    cmd = ('source "$1" && op_project_inventory "$2" >/dev/null && '
           'cat "$(op_inventory_path "$2")"')
    r = subprocess.run(["bash", "-c", cmd, "_", ENV, str(pid)],
                       capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        raise RuntimeError(
            "op-status: could not read the OpenProject inventory — "
            f"{r.stderr.strip()[:400]}. Refusing to create anything, because a "
            "duplicate check that could not look is not a duplicate check. "
            "Tracker NOT synced.")
    out = {}
    for line in r.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if row.get("subject") and row.get("id"):
            out[row["subject"]] = int(row["id"])
    return out


TASK_FILE = re.compile(r"task-(\d+)")


def cmd_bootstrap(a, mp):
    """One Task work package per task file, the file attached, recorded in the map.

    The map is saved after EVERY work package, not once at the end. A failure
    part-way through otherwise leaves real work packages in the tracker that
    nothing in the repo remembers, and the next run recreates every one of them.
    """
    d = os.path.join(TASKS, a.story_key)
    if not os.path.isdir(d):
        raise RuntimeError(f"op-status: no task files at {d}. Run create-tasks first.")
    story_wp = wp_for(mp, a.story_key)
    pid = project_id(mp)
    type_task = type_id(mp, "task")
    wps = mp.setdefault("work_packages", {})

    files, ignored = [], []
    for f in sorted(os.listdir(d)):
        (files if (f.endswith(".md") and TASK_FILE.match(f)) else ignored).append(f)
    if ignored:
        print(f"bootstrap: ignoring {len(ignored)} non-task file(s) in {d}: "
              f"{', '.join(ignored)}", file=sys.stderr)
    if not files:
        raise RuntimeError(f"op-status: {d} holds no task-<n>-*.md files. Run create-tasks first.")
    files.sort(key=lambda f: (int(TASK_FILE.match(f).group(1)), f))

    inventory = tracker_inventory(pid)
    created = adopted = present = 0
    for i, f in enumerate(files):
        key = task_key(a.story_key, f[:-3])
        if wps.get(key, {}).get("wp_id"):
            present += 1
            print(f"have {key}")
            continue
        path = os.path.join(d, f)
        title = open(path).readline().lstrip("# ").strip()
        subject = f"Story {a.story_key.split('-')[0]}.{a.story_key.split('-')[1]} / {title}"[:255]
        if subject in inventory:
            # On a duplicate: adopt, do not create.
            wps[key] = {"wp_id": inventory[subject], "parent_wp_id": story_wp, "title": subject}
            save_map(mp)
            adopted += 1
            print(f"adopted #{inventory[subject]}  {subject[:70]}")
            continue
        res = op("create_work_package",
                 {"project_id": pid, "subject": subject, "type_id": type_task,
                  "description": open(path).read()}, 910 + i)
        wp = int(res.get("id") or (res.get("work_package") or {}).get("id"))
        # Recorded before the parent and attachment calls: if either fails, the
        # work package still exists in the tracker and the map must already know
        # about it, or the retry creates a second one.
        wps[key] = {"wp_id": wp, "parent_wp_id": story_wp, "title": subject}
        save_map(mp)
        op("set_work_package_parent", {"work_package_id": wp, "parent_id": story_wp}, 940 + i)
        att = op("add_work_package_attachment",
                 {"work_package_id": wp, "file_data": base64.b64encode(open(path, "rb").read()).decode(),
                  "filename": f, "content_type": "text/markdown", "description": "dev-tasks task file"}, 970 + i)
        wps[key]["task_attachment_id"] = att.get("attachment_id") or att.get("id")
        save_map(mp)
        created += 1
        print(f"created #{wp}  {subject[:70]}")
    print(f"bootstrap: {created} created, {adopted} adopted, {present} already in the map")


DEFAULT_HEADER = (
    "# Auto-generated by SKAD-BMM OpenProject sync\n"
    "# Managed by: create-epics-and-stories step-05 (openproject-epics-sync.py),\n"
    "# the openproject-sync workflow and _skad/bmm/lib/op-status.py\n"
    "# Do not edit manually — values are updated automatically during the dev workflow\n"
    "#\n"
    "# Story keys equal the sprint-status keys (<epic>-<story>-<kebab title>);\n"
    "# task keys are <story key>/<task file stem>.\n")


def save_map(mp):
    """Rewrite the map, keeping whatever header comments it already carried.

    yaml.safe_dump drops comments, so a writer that supplies its own header
    silently erases any documentation the file had accumulated — a little more
    of it on every status update, and nothing in the diff explains why.
    """
    header = ""
    try:
        with open(MAP) as fh:
            for line in fh:
                if line.startswith("#") or not line.strip():
                    header += line
                else:
                    break
    except FileNotFoundError:
        pass
    with open(MAP, "w") as fh:
        fh.write(header or DEFAULT_HEADER)
        yaml.safe_dump(mp, fh, sort_keys=False, allow_unicode=True, width=120)


# --- the check: tracker vs sprint-status vs task files ----------------------
#
# Both tables below name states in `status_map`, never OpenProject status TITLES.
# The writers resolve the same names through the same map, so `check` verifies the
# exact id a write would have set — on an instance whose statuses are named or
# numbered differently, both halves move together and the check keeps meaning.

SPRINT_TO_STATE = {"backlog": None, "ready-for-dev": None, "in-progress": "in_progress",
                   "review": "review", "done": "done", "blocked": STORY_STATE["blocked"]}
TASK_TO_STATE = {"ready-for-task": None, "in-dev": "in_progress", "in-dev-complete": "in_progress",
                 "in-review": "in_progress", "in-test": "in_progress", "passed": "done",
                 "failed": "failed"}


def live_status(wp_id):
    """(id, title) of the work package's current status. The id is what is compared;
    the title is only ever used to make a drift line readable."""
    d = op("get_work_package", {"work_package_id": wp_id}, 990)
    w = d.get("work_package", d)
    link = (w.get("_links") or {}).get("status") or {}
    href = link.get("href") or ""
    m = re.search(r"/statuses/(\d+)", href)
    sid = int(m.group(1)) if m else None
    title = link.get("title") or w.get("status") or "?"
    if sid is None:
        raise RuntimeError(f"op-status: #{wp_id} returned no status id ({href!r}); "
                           "cannot verify the tracker. Treating as UNCHECKED, not as agreement.")
    return sid, title


def cmd_check(a, mp):
    """Every story and task whose local state implies a tracker state must match it.

    Three outcomes, never two: agreed, DISAGREED, or COULD NOT VERIFY. A work
    package whose status could not be read is never counted as agreement, and one
    unreadable work package never discards the drift already found beside it —
    which is what an exception escaping this loop used to do.
    """
    sprint = yaml.safe_load(open(SPRINT)) or {}
    dev = sprint.get("development_status") or {}
    drift, unverified = [], []
    checked = skipped = 0

    def compare(label, wp_id, want, want_name, because):
        nonlocal checked
        try:
            got, got_title = live_status(wp_id)
        except RuntimeError as ex:
            unverified.append(f"{label}: {ex}")
            return
        checked += 1
        if got != want:
            drift.append(f"{label}: {because} implies status {want} ({want_name}), "
                         f"tracker says {got} ({got_title}) (#{wp_id})")

    for key, raw in dev.items():
        if not re.match(r"\d+-\d+-", key):
            continue
        if a.story_key and key != a.story_key:
            continue
        want_name = SPRINT_TO_STATE.get(str(raw).split()[0])
        if want_name is None:
            # backlog / ready-for-dev imply nothing about the tracker. Counted,
            # so a run that verified nothing cannot print the same line as a run
            # that verified everything.
            skipped += 1
            continue
        entry = (mp.get("work_packages") or {}).get(key)
        if not entry or not entry.get("wp_id"):
            drift.append(f"story {key}: local {raw} but no work package in the map")
            continue
        compare(f"story {key}", entry["wp_id"], status_id(mp, want_name), want_name, f"local {raw}")
        d = os.path.join(TASKS, key)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if not f.endswith(".md"):
                continue
            m = re.search(r"^\*\*Status:\*\* (\S+)", open(os.path.join(d, f)).read(), re.M)
            if not m:
                continue
            twant_name = TASK_TO_STATE.get(m.group(1))
            if twant_name is None:
                skipped += 1
                continue
            tentry = (mp.get("work_packages") or {}).get(task_key(key, f[:-3]))
            if not tentry or not tentry.get("wp_id"):
                drift.append(f"task {key}/{f[:-3]}: file says {m.group(1)} but no work package")
                continue
            compare(f"task {key}/{f[:-3]}", tentry["wp_id"], status_id(mp, twant_name),
                    twant_name, f"file says {m.group(1)}")

    for line in drift:
        print(f"DRIFT: {line}", file=sys.stderr)
    for line in unverified:
        print(f"UNVERIFIED: {line}", file=sys.stderr)
    print(f"op-status check: {checked} work packages compared, {len(drift)} disagreements, "
          f"{len(unverified)} could not be verified, {skipped} carry no tracker implication")
    if drift or unverified:
        return 1
    if checked == 0:
        # Exit 2, not 0. "Nothing disagreed" and "nothing was looked at" are
        # different facts, and a caller that sees only the exit code must be able
        # to tell them apart — which is the whole reason this command exists.
        print("op-status check: nothing was compared — this is NOT a verified tracker. "
              "Every item is in a local state that implies no tracker status, or has no "
              "work package. Exit 2 = nothing to compare, not agreement.", file=sys.stderr)
        return 2
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("task"); t.add_argument("story_key"); t.add_argument("stem"); t.add_argument("phase"); t.add_argument("--note")
    s = sub.add_parser("story"); s.add_argument("story_key"); s.add_argument("state"); s.add_argument("--note")
    e = sub.add_parser("epic"); e.add_argument("n"); e.add_argument("state"); e.add_argument("--note")
    b = sub.add_parser("bug"); b.add_argument("story_key"); b.add_argument("subject"); b.add_argument("--body-file"); b.add_argument("--note")
    bc = sub.add_parser("bug-close"); bc.add_argument("wp_id"); bc.add_argument("--note")
    bo = sub.add_parser("bootstrap"); bo.add_argument("story_key")
    c = sub.add_parser("check"); c.add_argument("story_key", nargs="?")
    a = p.parse_args()
    try:
        mp = load_map()
        rc = {"task": cmd_task, "story": cmd_story, "epic": cmd_epic, "bug": cmd_bug,
              "bug-close": cmd_bugclose, "bootstrap": cmd_bootstrap,
              "check": cmd_check}[a.cmd](a, mp)
    except RuntimeError as ex:
        print(str(ex), file=sys.stderr)
        sys.exit(1)
    sys.exit(rc or 0)


if __name__ == "__main__":
    main()
