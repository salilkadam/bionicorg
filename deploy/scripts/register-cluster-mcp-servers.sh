#!/usr/bin/env bash
# register-cluster-mcp-servers.sh — Register the cluster-local MCP servers
# (deploy/mcp/bionic-org-mcp-servers.json) as Paperclip tool connections.
#
# Idempotent: re-running updates nothing that already exists (matched by the
# "Loc-" display name) and creates the rest.
#
# Every server is addressed via internal cluster DNS
# (http://<svc>.<ns>.svc.cluster.local:<port>/mcp) with auth kind "none":
# traffic never leaves the cluster and the MCP servers behind the mcp
# ingress's API-key wall are open on the internal path. This works because
# PAPERCLIP_DEPLOYMENT_EXPOSURE=private (see helm values) lets the SSRF
# endpoint guard accept private-network URLs.
#
# Usage:
#   PAPERCLIP_BOARD_TOKEN=<pcp_board_...> \
#   ./deploy/scripts/register-cluster-mcp-servers.sh \
#       [--url http://localhost:3100] [--catalog deploy/mcp/bionic-org-mcp-servers.json]
#
# Run from inside the cluster (e.g. kubectl exec into the app pod with the
# catalog copied in) or anywhere that can reach the Paperclip API.
set -euo pipefail

API="http://localhost:3100"
CATALOG="deploy/mcp/bionic-org-mcp-servers.json"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) API="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
: "${PAPERCLIP_BOARD_TOKEN:?PAPERCLIP_BOARD_TOKEN (board API key) is required}"

PAPERCLIP_API="$API" PAPERCLIP_BOARD_TOKEN="$PAPERCLIP_BOARD_TOKEN" node - "$CATALOG" <<'EOF'
const fs = require("fs");
const catalog = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const API = process.env.PAPERCLIP_API;
const TOKEN = process.env.PAPERCLIP_BOARD_TOKEN;
const CID = catalog.companyId;

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
  if (!res.ok) {
    throw new Error(path + " -> " + res.status + " " + body.slice(0, 200));
  }
  return json;
}

(async () => {
  const existing = await api("/companies/" + CID + "/tools/connections");
  const rows = Array.isArray(existing) ? existing : (existing.connections || existing.items || []);
  const byName = new Map(rows.map((r) => [r.name, r]));

  for (const s of catalog.servers) {
    if (s.status !== "ready") {
      console.log("skip  " + s.displayName + " (" + s.status + ")");
      continue;
    }
    if (byName.has(s.displayName)) {
      console.log("exist " + s.displayName);
      continue;
    }
    // authKind "none" is the internal-DNS default. Servers that sit behind
    // Kong's key-auth wall (e.g. Loc-Google Workspace) must be addressed via
    // the gateway URL with a stored apikey header: the server trusts only
    // Kong-injected consumer headers, so sending the apikey straight to the
    // internal DNS URL 401s. The apikey value comes from the environment
    // named by auth.valueEnv (e.g. mcp_api_key, ESO-synced from Vault
    // shared/api-keys) and is stored as a Paperclip managed secret.
    let credentialRefs = [];
    let authKind = "none";
    if (s.auth && s.auth.kind === "apikey_header") {
      const value = process.env[s.auth.valueEnv];
      if (!value) throw new Error(s.displayName + ": missing env " + s.auth.valueEnv);
      const secret = await api("/companies/" + CID + "/secrets", {
        method: "POST",
        body: JSON.stringify({
          name: s.displayName + " apikey",
          key: s.key + "-apikey",
          value,
          description: "Kong gateway apikey for " + s.displayName + " (source: Vault shared/api-keys " + s.auth.valueEnv + ")",
        }),
      });
      credentialRefs = [{
        name: s.key + "-apikey",
        secretId: secret.id,
        placement: "header",
        key: s.auth.headerName || "apikey",
      }];
      authKind = "api_key";
    }
    const app = await api("/companies/" + CID + "/tools/applications", {
      method: "POST",
      body: JSON.stringify({
        applicationKey: s.key,
        name: s.displayName,
        description: s.description,
        type: "mcp_http",
        metadata: { source: "cluster-mcp-catalog", internalUrl: s.url },
      }),
    });
    const conn = await api("/companies/" + CID + "/tools/connections", {
      method: "POST",
      body: JSON.stringify({
        applicationId: app.id,
        name: s.displayName,
        connectionPurpose: "tool",
        transport: "mcp_remote",
        authKind,
        credentialPolicy: "shared",
        status: "active",
        enabled: true,
        config: { url: s.url },
        transportConfig: { url: s.url, sourceTemplateKey: s.key, connectionMethodKey: "managed" },
        ...(credentialRefs.length ? { credentialRefs } : {}),
      }),
    });
    console.log("creat " + s.displayName + " -> " + conn.id + " (" + s.toolCount + " tools)");
    try {
      await api("/tool-connections/" + conn.id + "/health-check", { method: "POST", body: "{}" });
    } catch (e) { console.log("      health-check: " + String(e.message).slice(0, 80)); }
    try {
      const cat = await api("/tool-connections/" + conn.id + "/catalog/refresh", { method: "POST", body: "{}" });
      console.log("      catalog: " + JSON.stringify(cat && cat.count != null ? cat.count : (cat && cat.entries ? cat.entries.length : "ok")));
    } catch (e) { console.log("      catalog: " + String(e.message).slice(0, 80)); }
  }
})();
EOF
