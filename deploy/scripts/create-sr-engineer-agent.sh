#!/usr/bin/env bash
# create-sr-engineer-agent.sh — Create (or verify) the "Sr. Engineer" agent.
#
# Sr. Engineer is an IT-department engineer that reports to the CIO, monitors
# Paperclip run failures on a 5-minute heartbeat, retries what it can, fixes
# known patterns, and goes back to sleep. Its brain is the Claude subscription
# via the claude_local adapter; its runbook is deploy/agents/sr-engineer-AGENTS.md.
#
# Idempotent: if an agent named "Sr. Engineer" already exists in the company it
# prints the existing id and exits 0 without creating a duplicate.
#
# Usage:
#   PAPERCLIP_BOARD_TOKEN=<pcp_board_...> \
#   ./deploy/scripts/create-sr-engineer-agent.sh [--url http://localhost:3100]
#
# Run from inside the cluster (kubectl exec into the app pod, with this repo's
# deploy/ directory copied in) or anywhere that can reach the Paperclip API.
#
# After creation (Claude subscription auth — claude_local has NO device login;
# heartbeat stays disabled until bound). The token lives in Vault
# (shared/api-keys -> claude_subscription_token), synced by ESO into the pod
# env CLAUDE_CODE_OAUTH_TOKEN:
#   1. Inside the app pod, submit the stored token (never echo it):
#        curl -X POST -H "Authorization: Bearer $(cat /tmp/.bk)" \
#          -H "Content-Type: application/json" \
#          -d "{\"token\":\"$CLAUDE_CODE_OAUTH_TOKEN\"}" \
#          $API/api/companies/<cid>/claude-oauth-token
#   2. Bind the stored token to the agent:
#        PATCH /api/agents/<id>  {"applyStoredClaudeLogin":true}
#   3. Enable the heartbeat:
#        PATCH /api/agents/<id>
#        {"runtimeConfig":{"heartbeat":{"enabled":true,"intervalSec":300,"maxConcurrentRuns":1}}}
set -euo pipefail

API="http://localhost:3100"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) API="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
: "${PAPERCLIP_BOARD_TOKEN:?PAPERCLIP_BOARD_TOKEN (board API key) is required}"

RUNBOOK="$(dirname "$0")/../agents/sr-engineer-AGENTS.md"
[[ -f "$RUNBOOK" ]] || { echo "runbook not found: $RUNBOOK" >&2; exit 1; }

PAPERCLIP_API="$API" PAPERCLIP_BOARD_TOKEN="$PAPERCLIP_BOARD_TOKEN" \
PAPERCLIP_RUNBOOK="$RUNBOOK" node - <<'EOF'
const fs = require("fs");
const API = process.env.PAPERCLIP_API;
const TOKEN = process.env.PAPERCLIP_BOARD_TOKEN;
const RUNBOOK_PATH = process.env.PAPERCLIP_RUNBOOK;

const CID = "62d63984-df6c-49be-981c-1273f68a451c"; // Reliora Inc
const CIO_ID = "fb6429f4-d521-4034-ad56-dc3f951711bf";
const NAME = "Sr. Engineer";

async function api(path, init = {}) {
  const res = await fetch(API + "/api" + path, {
    ...init,
    headers: {
      Authorization: "Bearer " + TOKEN,
      "Content-Type": "application/json",
      ...(init.headers || {}),
    },
  });
  const body = await res.text();
  let json = null;
  try { json = JSON.parse(body); } catch {}
  if (!res.ok) throw new Error(path + " -> " + res.status + " " + body.slice(0, 300));
  return json;
}

(async () => {
  const agents = await api(`/companies/${CID}/agents`);
  const list = Array.isArray(agents) ? agents : agents.agents || [];
  const existing = list.find((a) => a.name === NAME);
  if (existing) {
    console.log(`already exists: ${existing.id} (status=${existing.status})`);
    console.log(`heartbeat=${JSON.stringify((existing.runtimeConfig || {}).heartbeat || {})}`);
    return;
  }

  const runbook = fs.readFileSync(RUNBOOK_PATH, "utf8");
  const body = {
    name: NAME,
    role: "engineer",
    title: "Senior Engineer",
    icon: "terminal",
    reportsTo: CIO_ID,
    capabilities:
      "Monitors Paperclip run failures and recovery backlog every 5 minutes; retries transient failures, applies known-pattern fixes, escalates cluster/operator actions with precise diagnoses.",
    adapterType: "claude_local",
    adapterConfig: {},
    instructionsBundle: { entryFile: "AGENTS.md", files: { "AGENTS.md": runbook } },
    runtimeConfig: {
      heartbeat: { enabled: false, intervalSec: 300, maxConcurrentRuns: 1 },
    },
    budgetMonthlyCents: 0,
    metadata: { department: "IT", createdBy: "deploy/scripts/create-sr-engineer-agent.sh" },
  };
  const created = await api(`/companies/${CID}/agents`, {
    method: "POST",
    body: JSON.stringify(body),
  });
  const id = created.id || created.agent?.id;
  console.log(`created: ${id}`);
  console.log("NEXT: bootstrap Claude auth from the Vault-synced pod env, bind, enable heartbeat:");
  console.log(`  POST  /api/companies/${CID}/claude-oauth-token {"token":"$CLAUDE_CODE_OAUTH_TOKEN"}  (inside app pod)`);
  console.log(`  PATCH /api/agents/${id} {"applyStoredClaudeLogin":true}`);
  console.log(`  PATCH /api/agents/${id} {"runtimeConfig":{"heartbeat":{"enabled":true,"intervalSec":300,"maxConcurrentRuns":1}}}`);
})().catch((e) => { console.error(e.message); process.exit(1); });
EOF
