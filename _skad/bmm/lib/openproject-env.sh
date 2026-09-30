#!/usr/bin/env bash
# OpenProject MCP bridge — endpoint resolution for SKAD workflows.
#
# Source this at the top of EVERY bash block that talks to OpenProject:
#     source "$(git rev-parse --show-toplevel)/_skad/bmm/lib/openproject-env.sh"
#
# Each Bash tool invocation is a FRESH SHELL, so shell variables do not survive
# between blocks of a workflow. Re-sourcing in every block is the only thing
# that works — a single "resolve the endpoint once" step at the top of a
# workflow silently leaves every later block with an empty URL.
#
# Why this file exists: the endpoint used to be hard-coded as a specific private
# host in 14 places across the workflow files, while module.yaml declared an
# `openproject_mcp_url` variable that NOTHING consumed. Installs that configured
# the variable were ignored, and installs that did not still pointed at someone
# else's server. The endpoint is configuration, not a constant.

_op_root="${SKAD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Resolution order. First hit wins; there is deliberately NO built-in default,
# because a baked-in default is how a private endpoint ends up in every install.
#   1. $SKAD_OPENPROJECT_MCP_URL          (env override, for CI)
#   2. _skad/openproject/config.yaml      (module config, written by the installer)
#   3. _skad/bmm/config.yaml              (project config)
#   4. _skad/core/config.yaml
# NOTE: `eval "$(cmd)" || handler` does NOT work — eval reports the status of the
# string it evaluated, not of the command substitution, so the handler is dead
# code. Capture the output and the status separately.
_op_resolved=$(python3 - "$_op_root" "${SKAD_OPENPROJECT_MCP_URL:-}" <<'EOF'
import os, sys, shlex
try:
    import yaml
except ImportError:
    sys.stderr.write("⚠️  OpenProject: PyYAML not installed; cannot read config. Status NOT synced.\n")
    sys.exit(1)

root, env_url = sys.argv[1], sys.argv[2]
candidates = ["_skad/openproject/config.yaml", "_skad/bmm/config.yaml", "_skad/core/config.yaml"]

url = env_url or ""
src = "$SKAD_OPENPROJECT_MCP_URL" if env_url else ""
apikey_env = timeout = project_id = ""

for rel in candidates:
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        continue
    try:
        c = yaml.safe_load(open(p)) or {}
    except Exception as e:
        sys.stderr.write(f"⚠️  OpenProject: {rel} is not valid YAML ({e}). Skipping it.\n")
        continue
    if not url and c.get("openproject_mcp_url"):
        url, src = str(c["openproject_mcp_url"]), rel
    if not apikey_env and c.get("openproject_mcp_apikey_env"):
        apikey_env = str(c["openproject_mcp_apikey_env"])
    if not timeout and c.get("openproject_mcp_timeout_seconds"):
        timeout = str(c["openproject_mcp_timeout_seconds"])
    if not project_id and c.get("openproject_id") is not None:
        project_id = str(c["openproject_id"])

if not url:
    sys.stderr.write(
        "⚠️  OpenProject: no endpoint configured. Status NOT synced.\n"
        "    Set `openproject_mcp_url` in one of:\n"
        "      " + "\n      ".join(candidates) + "\n"
        "    or export SKAD_OPENPROJECT_MCP_URL.\n"
        "    Install the module with `skad install openproject` to be prompted for it.\n"
    )
    sys.exit(1)

print(f"OP_MCP_URL={shlex.quote(url)}")
print(f"OP_MCP_URL_SOURCE={shlex.quote(src)}")
print(f"OP_MCP_APIKEY_ENV={shlex.quote(apikey_env)}")
print(f"OP_TIMEOUT={shlex.quote(timeout or '30')}")
print(f"OP_PROJECT_ID={shlex.quote(project_id)}")
EOF
)
_op_rc=$?
if [ $_op_rc -ne 0 ]; then
  echo "⚠️  OpenProject: endpoint resolution failed (rc=$_op_rc). Status NOT synced." >&2
  unset _op_resolved _op_rc
  return 1 2>/dev/null || exit 1
fi
eval "$_op_resolved"
unset _op_resolved _op_rc

if [ -z "${OP_MCP_URL:-}" ]; then
  echo "⚠️  OpenProject: endpoint resolution produced no URL. Status NOT synced." >&2
  return 1 2>/dev/null || exit 1
fi

# Send an apikey header only when the configured env var is actually set.
# An endpoint behind an API gateway (Kong key-auth and friends) returns
# 401 {"message":"No API key found in request"} without one; an in-cluster
# service address usually needs no key at all.
OP_AUTH_ARGS=()
if [ -n "${OP_MCP_APIKEY_ENV:-}" ] && [ -n "${!OP_MCP_APIKEY_ENV:-}" ]; then
  OP_AUTH_ARGS=(-H "apikey: ${!OP_MCP_APIKEY_ENV}")
fi

# op_call <tool> <args-json> [id] -> prints the tool's result text on success.
# Returns non-zero on ANY failure. Never prints a partial or misleading result.
#
# Bounds every call with -m "$OP_TIMEOUT" so a hung bridge fails fast and
# visibly rather than stalling the workflow.
#
# Reports the CONSEQUENCE ("Status NOT synced"), not just the error, because a
# sync that quietly does nothing is indistinguishable from one that had nothing
# to do.
op_call() {
  local tool=$1 args=$2 id=${3:-1} body resp http rc
  # Defence in depth: `return 1` from a sourced file returns from the source,
  # it does NOT stop the calling block. A caller that ignores the resolution
  # failure must still not reach the network with an empty endpoint.
  if [ -z "${OP_MCP_URL:-}" ]; then
    echo "⚠️  OpenProject: [$tool] called with no endpoint resolved — the source step failed. Status NOT synced." >&2
    return 1
  fi
  body=$(printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}' "$id" "$tool" "$args")
  # The body goes over STDIN, not argv. A base64 attachment of any real size
  # blows ARG_MAX and curl dies with "Argument list too long" (rc=126) — which
  # is exactly what happened the first time this library was asked to attach a
  # 100 KB document. --data-binary @- has no size ceiling.
  resp=$(printf '%s' "$body" | curl -s -m "$OP_TIMEOUT" -w '\n%{http_code}' -X POST "$OP_MCP_URL" \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    ${OP_AUTH_ARGS[@]+"${OP_AUTH_ARGS[@]}"} --data-binary @-)
  rc=$?
  http=$(printf '%s' "$resp" | tail -n1)
  resp=$(printf '%s' "$resp" | sed '$d')

  if [ $rc -ne 0 ]; then
    echo "⚠️  OpenProject: [$tool] transport failure (curl rc=$rc, endpoint $OP_MCP_URL). Status NOT synced." >&2
    return 1
  fi
  if [ "$http" != "200" ]; then
    echo "⚠️  OpenProject: [$tool] HTTP $http from $OP_MCP_URL. Status NOT synced." >&2
    if [ "$http" = "401" ] || [ "$http" = "403" ]; then
      echo "    The endpoint requires authentication. Set \`openproject_mcp_apikey_env\` in config to the name of an env var holding the key, and export that var." >&2
    fi
    echo "    Body: $(printf '%s' "$resp" | head -c 200)" >&2
    return 1
  fi

  printf '%s' "$resp" | OP_EXPECT_ID="$id" OP_MCP_URL="$OP_MCP_URL" python3 -c "
import json,sys,os
try:
    d=json.load(sys.stdin)
except Exception as e:
    sys.stderr.write('⚠️  OpenProject: response was not JSON (%s). Status NOT synced.\n' % e); sys.exit(1)
if 'error' in d:
    sys.stderr.write('⚠️  OpenProject: JSON-RPC error — %s. Status NOT synced.\n' % d['error']); sys.exit(1)

# A 200 carrying JSON that is not a tools/call result is NOT success. Before this
# check, any JSON body without 'error' and without isError returned rc=0 and
# printed '{}' — so a URL pointing at a gateway's default JSON route, a health
# endpoint, or the wrong path produced a silent no-op that callers then parsed
# into an empty work-package id and reported as 'WP created → WP #'.
# Absence and failure must never share a representation.
if 'result' not in d:
    sys.stderr.write('⚠️  OpenProject: response has no JSON-RPC result — %s is probably not an MCP endpoint. Status NOT synced. Body: %s\n'
                     % (os.environ.get('OP_MCP_URL','the endpoint'), json.dumps(d)[:200])); sys.exit(1)
r=d.get('result') or {}
content = r.get('content')
if not isinstance(content, list) or not content or 'text' not in (content[0] or {}):
    sys.stderr.write('⚠️  OpenProject: result carried no content — the bridge answered but returned nothing usable. Status NOT synced. Body: %s\n'
                     % json.dumps(d)[:200]); sys.exit(1)
text=content[0].get('text','')

# The response must answer the request we sent.
if d.get('id') is not None and str(d.get('id')) != os.environ.get('OP_EXPECT_ID',''):
    sys.stderr.write('⚠️  OpenProject: response id %r does not match request id %r. Status NOT synced.\n'
                     % (d.get('id'), os.environ.get('OP_EXPECT_ID',''))); sys.exit(1)
# The bridge answers an unknown or failed tool with HTTP 200 and isError:true,
# carrying a PLAIN-TEXT message where callers expect JSON. Without this check a
# tool failure is indistinguishable from success at the transport layer.
if r.get('isError'):
    sys.stderr.write('⚠️  OpenProject: tool reported failure — %s. Status NOT synced.\n' % text.strip()); sys.exit(1)
print(text or '{}')
"
}

# get_from_map <dotted.path> — read a value out of openproject-map.yaml.
# The sync workflows call this; before it was defined here it existed in no file
# in either repo, so every call was a silent empty string.
# Prints nothing and returns non-zero when the map or the key is absent, so an
# unset id can never be interpolated into a request as an empty string.
OP_MAP_FILE="${OP_MAP_FILE:-$_op_root/_skad/bmm/openproject-map.yaml}"
get_from_map() {
  local key=$1
  if [ ! -f "$OP_MAP_FILE" ]; then
    echo "⚠️  OpenProject: $OP_MAP_FILE not found — run create-epics-and-stories step-05 first. Status NOT synced." >&2
    return 1
  fi
  python3 - "$OP_MAP_FILE" "$key" <<'EOF'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1])) or {}
cur = doc
for seg in sys.argv[2].split('.'):
    if not isinstance(cur, dict) or seg not in cur:
        sys.stderr.write("\u26a0\ufe0f  OpenProject: key %r not in the map. Status NOT synced.\n" % sys.argv[2])
        sys.exit(1)
    cur = cur[seg]
if cur is None or cur == "":
    sys.stderr.write("\u26a0\ufe0f  OpenProject: key %r is empty in the map. Status NOT synced.\n" % sys.argv[2])
    sys.exit(1)
print(cur)
EOF
}

# ── Duplicate prevention ─────────────────────────────────────────────────────
#
# STANDING RULE: before creating any epic, feature or story, read what is
# ALREADY in OpenProject. Not the local map — OpenProject.
#
# openproject-map.yaml records only what SKAD itself created. It cannot see a
# work package made by hand, by another tool, by a teammate, or by an earlier
# run whose map was lost. Checking the map and calling that a duplicate check is
# verifying against our own record instead of against the system of record —
# and the map is exactly the file most likely to be missing when it matters.

# op_inventory_path <project_id> — deterministic, so the reader and the writer
# agree without passing state through a subshell.
op_inventory_path() { echo "${TMPDIR:-/tmp}/op-inventory-$1.jsonl"; }

# op_project_inventory <project_id> — write every work package to the inventory
# file, then print the count.
#
# CLOSED ITEMS ARE NOT OPTIONAL EITHER. `status` defaults to "open", so the listing
# omits closed work packages (observed 2026-09-12: 154 -> 153 the moment a story was
# closed) and a duplicate check against it would recreate anything already finished.
# PAGINATION IS NOT OPTIONAL. The API returns 20 per page by default. Reading
# the first page and treating it as the whole project is how a duplicate check
# reports "not found" for something sitting on page 2 — a mistake made against
# this very project before this helper existed.
op_project_inventory() {
  local pid=$1 f st offset total have got n
  f=$(op_inventory_path "$pid"); : > "$f"
  # Two explicit passes rather than one `status=all` pass. "all" works — it means
  # "no status filter" — but it yields a single aggregate total, so a listing that
  # silently returned only the open half would still satisfy the completeness check
  # below. Asking for each half by name gives each its own total to verify against,
  # and never depends on the bridge treating an unrecognised status as "no filter".
  for st in open closed; do
    offset=1; total=""; have=0
    while : ; do
      page=$(op_call list_work_packages "{\"project_id\":$pid,\"status\":\"$st\",\"page_size\":100,\"offset\":$offset}" 9001) || {
        rm -f "$f"; return 1; }
      n=$(printf '%s' "$page" | python3 -c "
import json,sys
d=json.load(sys.stdin)
w=d if isinstance(d,list) else d.get('work_packages', d.get('_embedded',{}).get('elements',[]))
t=d.get('total', len(w)) if isinstance(d,dict) else len(w)
out=open(sys.argv[1],'a')
for x in w:
    out.write(json.dumps({'id':x.get('id'),'subject':x.get('subject','')})+'\n')
print(len(w), t)
" "$f") || { rm -f "$f"; return 1; }
      got=$(echo "$n" | cut -d' ' -f1); total=$(echo "$n" | cut -d' ' -f2)
      have=$((have+got))
      { [ "$got" -eq 0 ] || [ "$have" -ge "${total:-0}" ]; } && break
      offset=$((offset+1))
    done
    if [ -n "$total" ] && [ "$have" -lt "$total" ]; then
      echo "⚠️  OpenProject: read $have of $total $st work packages — inventory INCOMPLETE. A duplicate check against it is unsafe; refusing. Nothing created." >&2
      rm -f "$f"; return 1
    fi
  done
  wc -l < "$f" | tr -d ' '
}

# op_find_duplicate <project_id> "<subject>"
#
# Exit codes are the contract, because "found nothing" and "could not look" must
# never look alike:
#   0 — checked, no duplicate. Safe to create.
#   1 — checked, DUPLICATE FOUND (printed as id<TAB>subject). Do not create.
#   2 — COULD NOT CHECK (no inventory). Do not create; run op_project_inventory.
op_find_duplicate() {
  local pid=$1 subject=$2 f
  f=$(op_inventory_path "$pid")
  if [ ! -s "$f" ]; then
    echo "⚠️  OpenProject: no inventory for project $pid — run op_project_inventory first. REFUSING to report 'no duplicate' from a check that did not run." >&2
    return 2
  fi
  python3 - "$f" "$subject" <<'EOF'
import json, re, sys
want = re.sub(r"\s+", " ", sys.argv[2]).strip().lower()
hits = []
for ln in open(sys.argv[1]):
    if not ln.strip():
        continue
    wp = json.loads(ln)
    have = re.sub(r"\s+", " ", wp.get("subject") or "").strip().lower()
    if have == want or (want and (want in have or have in want)):
        hits.append(wp)
for wp in hits:
    print(f"{wp['id']}\t{wp.get('subject')}")
sys.exit(1 if hits else 0)
EOF
}
