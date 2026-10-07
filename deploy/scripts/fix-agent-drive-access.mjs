#!/usr/bin/env node
/**
 * fix-agent-drive-access.mjs — make the Loc-* MCP tools reach agent RUNTIMEs
 * and teach every Reliora role agent the Google Drive publication rule.
 *
 * Root cause this script fixes: a connection being "active" with a company-
 * scoped tool PROFILE binding is NOT enough. buildPaperclipRuntimeMcpServers
 * only injects connections that are also PRESENT in tool_connection_installs
 * (company-scoped install rows cover every agent in the company). Without an
 * install row the tools are permitted-but-uninstalled and never appear in a run.
 *
 * What it does (idempotent):
 *  1. PUT /tool-connections/:id/installs -> [{targetType:"company"}] for every
 *     Loc-* connection (Loc-OpenProject keeps its two explicit agent installs).
 *  2. Patches each role agent's instructions entry file with the mandatory
 *     "Google Drive artifact publication" block naming its role folder id.
 *
 * Run from inside the bionic-org app pod (API on localhost:3100):
 *   PAPERCLIP_BOARD_TOKEN=pcp_board_... node - < fix-agent-drive-access.mjs
 * Mint the board token per the repo runbook (board_api_keys, short expiry) and
 * revoke it afterwards.
 */

import fs from "node:fs";

const BASE = process.env.PAPERCLIP_API_URL || "http://localhost:3100";
const TOKEN = process.env.PAPERCLIP_BOARD_TOKEN || fs.readFileSync("/tmp/.bk", "utf8").trim();
const COMPANY = "62d63984-df6c-49be-981c-1273f68a451c";
const H = { Authorization: `Bearer ${TOKEN}`, "Content-Type": "application/json" };

// connection id -> desired installs (PUT is a full replace of the install set)
const company = [{ targetType: "company", targetId: COMPANY }];
const INSTALLS = {
  "78ad5e0e-8c3c-43ab-af13-eff20e870998": company, // Loc-Google Workspace
  "7ba9667a-88e9-43e9-8082-6b57f66aab27": company, // Loc-AI
  "e72d695c-d42b-445e-b99d-8fa0591867f0": company, // Loc-API Gateway
  "9c736f34-b456-4b5a-a3a3-b8668548ef46": company, // Loc-Calculator
  "56fafa0a-9c37-4f5a-af91-046128bc9fcb": company, // Loc-ComfyUI
  "030832b3-74c8-4111-813c-6b92134ff38a": company, // Loc-DocFiles
  "5df0dec3-2f38-4b93-9d54-e8e08b339cd2": company, // Loc-FFmpeg
  "24baecfb-6268-4ad6-8579-b159da0ff804": company, // Loc-Figma
  "d41ff6a5-014a-4790-a489-b088ea13c885": company, // Loc-Gen3D
  "adbb9e9a-87ad-41cf-b883-2392de774b52": company, // Loc-GenImage
  "4f01758e-8445-4807-a8a6-b64a68cfdba9": company, // Loc-Langfuse
  "30e8184b-3e08-4b11-adc2-26e24b33540f": company, // Loc-Leffa
  "2fe5219f-3995-4eeb-815e-3531b6305903": company, // Loc-Mail
  "bb4a146b-4227-4e30-b0b5-14a78e0e21f0": company, // Loc-MeiliSearch
  "61d8070f-8182-4e2a-920b-4c88243a79ef": company, // Loc-MinIO
  "c260381e-53fe-42ed-a7a4-a3f7ba583146": company, // Loc-PDF
  "4f49eafd-5f0d-4082-be8b-dc8d9facdd5d": company, // Loc-Postgres
  "b67797f2-0848-4b08-adf2-3a97c4aca1cb": company, // Loc-Redis
  // Loc-OpenProject: company-wide PLUS the two pre-existing agent installs.
  "87bf8273-ae50-4037-9bc6-966f55e23173": [
    ...company,
    { targetType: "agent", targetId: "6c3d9ec8-604d-4621-98b3-761931c72225" },
    { targetType: "agent", targetId: "80214764-0c4d-43d5-b495-4cc8eee1b0d0" },
  ],
};

// agent id -> [role, Drive role-folder id] (folder ids pinned in deploy/README.md)
const AGENTS = {
  "73cae9f9-b419-48f1-b395-7e7e8c41048d": ["CEO", "1XGRgQDdZZOeDwVU9omlg6bNE5eEaZFeC"],
  "70499d70-c8de-4a11-b75f-70596e18e7e2": ["COO", "1-UGS4ohfHND3mi1LBIX4eJUln6mxw2ey"],
  "84d36e9e-e1f3-40d2-b36c-3c52140039a5": ["CMO", "10Ncj5HLJW0NdX0asahftmL1yPmO0W0P3"],
  "fb6429f4-d521-4034-ad56-dc3f951711bf": ["CIO", "1AZI8sLSO5hjx9B9D2HEfEfYysRg4kdCo"],
  "9ca37669-bd76-4389-97b5-b1c677fedac2": ["CLO", "1APCrCwB98knSn7GYjUXpURlhuVRISmZb"],
  "80214764-0c4d-43d5-b495-4cc8eee1b0d0": ["Project Manager", "1RPveSfN6e8zCmnJwNBk5o3G9JVooAimM"],
  "6c3d9ec8-604d-4621-98b3-761931c72225": ["Sr. Engineer", "16QRpoyGqlaVFTosGBRfoiBg0dkMzY0Y5"],
};

const MARKER = "Google Drive artifact publication";

async function api(method, path, body) {
  const r = await fetch(BASE + "/api" + path, {
    method,
    headers: H,
    body: body ? JSON.stringify(body) : undefined,
  });
  const t = await r.text();
  let j;
  try { j = JSON.parse(t); } catch { j = { raw: t.slice(0, 200) }; }
  return { s: r.status, j };
}

function driveBlock(role, folderId) {
  return [
    "## Google Drive artifact publication (mandatory)",
    "",
    "Final document artifacts MUST also be saved to the organization Google Drive space \"AI Team\" using the Google Workspace MCP tools (names start with gw_):",
    "",
    "- For every Drive call use tenant_id \"base\" and account \"salil-bionicaisolutions\".",
    `- Your role folder is "${role}" with folder_id \`${folderId}\`. Publish final artifacts there with gw_create_file (tenant_id, account, name, content, mime_type, folder_id).`,
    "- Cross-role or shared documents go to folder_id `1X3mLZ0IP1pJDJtMm5WZwoAzBb_qoh5dz` (\"_shared\").",
    "- Paste the returned webViewLink into the final issue comment of the task.",
    "- Never create files at the AI Team root (1MmJAx3Rkag90KSSlFISiVvkuWwvO38dK) or outside the AI Team space.",
    "- Work-in-progress drafts stay in the Paperclip issue/workspace; only final artifacts are published.",
    "- To list a folder use gw_list_files with query: '<folder_id>' in parents and trashed=false (there is no folder_id argument).",
  ].join("\n");
}

const report = { installs: [], agents: [] };

for (const [conn, installs] of Object.entries(INSTALLS)) {
  const r = await api("PUT", `/tool-connections/${conn}/installs`, { installs });
  report.installs.push(`${conn.slice(0, 8)} -> ${r.s}${r.s >= 300 ? " " + JSON.stringify(r.j).slice(0, 160) : ""}`);
}

for (const [id, [role, folderId]] of Object.entries(AGENTS)) {
  try {
    const b = await api("GET", `/agents/${id}/instructions-bundle`);
    if (b.s !== 200) { report.agents.push(`${id.slice(0, 8)} bundle-get ${b.s}`); continue; }
    const entry = b.j.entryFile || "AGENTS.md";
    const f = await api("GET", `/agents/${id}/instructions-bundle/file?path=${encodeURIComponent(entry)}`);
    if (f.s === 404) {
      // No entry file yet: create one (default role bundle is still appended at runtime).
      const u = await api("PUT", `/agents/${id}/instructions-bundle/file`, {
        path: entry, content: `# Role instructions\n\n${driveBlock(role, folderId)}`, baseRevisionId: null,
      });
      report.agents.push(`${id.slice(0, 8)} ${role} CREATE ${u.s}`);
      continue;
    }
    if (f.s !== 200) { report.agents.push(`${id.slice(0, 8)} file-get ${f.s}`); continue; }
    const content = typeof f.j.content === "string" ? f.j.content : "";
    if (content.includes(MARKER)) { report.agents.push(`${id.slice(0, 8)} SKIP already-patched`); continue; }
    const rev = f.j.baseRevisionId ?? f.j.revisionId ?? f.j.revision?.id ?? null;
    const u = await api("PUT", `/agents/${id}/instructions-bundle/file`, {
      path: entry, content: `${content ? content + "\n\n" : ""}${driveBlock(role, folderId)}`, baseRevisionId: rev,
    });
    report.agents.push(`${id.slice(0, 8)} ${role} PUT ${u.s}`);
  } catch (e) {
    report.agents.push(`${id.slice(0, 8)} ERR ${e.message}`);
  }
}

console.log(JSON.stringify(report, null, 1));
