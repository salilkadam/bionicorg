#!/usr/bin/env node
/**
 * Seed the "AI Team" Google Drive space for bionic-org (Paperclip).
 *
 * Creates (idempotently) one subfolder per org role under the approved
 * root folder, plus an OWNER.md inside each role folder and a README.md
 * at the root describing the ownership convention.
 *
 * Ownership convention (see deploy/README.md "Google Drive artifact space"):
 *   - The folder a document lives in declares its owning role.
 *   - Agents MUST pass their role folder's folder_id to gw_create_file.
 *   - Drive-side `owner` is always the single linked Google account
 *     (salil.kadam@bionicaisolutions.com); role ownership is expressed by
 *     folder placement + OWNER.md, not by Drive ACLs.
 *
 * How to run (from the bionic-org app pod context, via stdin):
 *   kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- \
 *     node - < deploy/scripts/gdrive-seed-ai-team.mjs
 *
 * Requires env: mcp_api_key (Kong apikey for the gworkspace MCP route).
 * Requires server image >= oauth-prm-3 (gw_create_folder; merged upstream in
 * Bionic-AI-Solutions/multitenant-mcp-servers main, PR #17).
 */

const ROOT = "1MmJAx3Rkag90KSSlFISiVvkuWwvO38dK"; // "AI Team" folder
const ENDPOINT = "https://mcp.baisoln.com/gworkspace/mcp";
const TENANT = "base";
const ACCOUNT = "salil-bionicaisolutions";

const HEADERS = {
  "Content-Type": "application/json",
  Accept: "application/json, text/event-stream",
  apikey: process.env.mcp_api_key,
};

// One folder per active org role. Agent IDs from the live `agents` table
// (bionicorg DB); duplicates are listed so OWNER.md stays honest.
const ROLES = [
  { folder: "CEO", title: "Chief Executive Officer", agents: ["9e8a1c51-2fd4-4c0f-b7ba-1db573465003", "73cae9f9-b419-48f1-b395-7e7e8c41048d"] },
  { folder: "COO", title: "Chief Operating Officer", agents: ["70499d70-c8de-4a11-b75f-70596e18e7e2", "05e8041a-41f1-476e-a15c-933267de7d63"] },
  { folder: "CMO", title: "Chief Marketing Officer", agents: ["c1dac855-85a3-450d-a751-3a438386ae50", "84d36e9e-e1f3-40d2-b36c-3c52140039a5"] },
  { folder: "CIO", title: "Head of Development", agents: ["fb6429f4-d521-4034-ad56-dc3f951711bf", "932269d9-f70c-45be-99cc-5feddeacdaea"] },
  { folder: "CLO", title: "Chief Legal Officer", agents: ["9ca37669-bd76-4389-97b5-b1c677fedac2", "784657f7-d38f-4b8d-a1f1-4332104bff90"] },
  { folder: "Project Manager", title: "Project Manager", agents: ["80214764-0c4d-43d5-b495-4cc8eee1b0d0"] },
  { folder: "Sr. Engineer", title: "Senior Engineer (error warden, IT dept)", agents: ["6c3d9ec8-604d-4621-98b3-761931c72225"] },
  { folder: "_shared", title: "Cross-role shared documents", agents: ["(all roles)"] },
];

let rpcId = 1;
async function call(name, args) {
  const r = await fetch(ENDPOINT, {
    method: "POST",
    headers: HEADERS,
    body: JSON.stringify({ jsonrpc: "2.0", id: rpcId++, method: "tools/call", params: { name, arguments: args } }),
  });
  const t = await r.text();
  const j = JSON.parse(t.slice(t.indexOf("{")));
  const env = j.result?.structuredContent ?? JSON.parse(j.result?.content?.[0]?.text);
  if (!env.success) throw new Error(`${name} failed: ${JSON.stringify(env.error).slice(0, 300)}`);
  return env.data;
}

const sleep = (ms) => new Promise((res) => setTimeout(res, ms));

async function listChildren(parentId) {
  // Drive query syntax requires the folder id in single quotes;
  // gw_list_files has no folder_id argument, only `query`.
  const data = await call("gw_list_files", {
    tenant_id: TENANT,
    account: ACCOUNT,
    query: `'${parentId}' in parents and trashed=false`,
    max_results: 100,
  });
  return data.files ?? data ?? [];
}

async function ensureFolder(parentId, name) {
  const existing = await listChildren(parentId);
  const hit = existing.find((f) => f.name === name && f.mimeType === "application/vnd.google-apps.folder");
  if (hit) return { ...hit, created: false };
  const data = await call("gw_create_folder", {
    tenant_id: TENANT,
    account: ACCOUNT,
    name,
    folder_id: parentId,
  });
  const mimeType = data.mimeType || data.type || "";
  if (mimeType && mimeType !== "application/vnd.google-apps.folder") {
    // No delete tool exists on this MCP server; flag loudly instead of
    // leaving silent junk. Delete manually and rerun.
    throw new Error(`Created "${name}" but mimeType is "${mimeType}" (not a folder). Manual cleanup needed.`);
  }
  return { ...data, created: true };
}

async function ensureFile(parentId, name, content, mimeType) {
  const existing = await listChildren(parentId);
  const hit = existing.find((f) => f.name === name && f.mimeType !== "application/vnd.google-apps.folder");
  if (hit) return { ...hit, created: false };
  const data = await call("gw_create_file", {
    tenant_id: TENANT,
    account: ACCOUNT,
    name,
    content,
    mime_type: mimeType,
    folder_id: parentId,
  });
  return { ...data, created: true };
}

function ownerMarkdown(role) {
  return [
    `# Owner: ${role.folder}`,
    "",
    `Role: ${role.title}`,
    `Paperclip agent(s): ${role.agents.join(", ")}`,
    "",
    "Every document in this folder is owned (accountable-to) the role above.",
    "Agents: always create files HERE with folder_id of your role folder.",
    "Drive `owner` field is the shared OAuth account; this file is the",
    "authoritative ownership record.",
    "",
    `Root: AI Team (${ROOT})`,
  ].join("\n");
}

const README = [
  "# AI Team — agent document space",
  "",
  "Managed by bionic-org (Paperclip). Layout and convention:",
  "",
  "- One folder per org role (CEO, COO, CMO, CIO, CLO, Project Manager, Sr. Engineer).",
  "- `_shared` for cross-role documents.",
  "- Each role folder contains an OWNER.md naming the accountable role + agent ids.",
  "- Agents MUST pass their role folder's folder_id when creating files",
  "  (gw_create_file → folder_id). Do not drop files at this root.",
  "- Reproduce/reseed this structure with:",
  "  `deploy/scripts/gdrive-seed-ai-team.mjs` (repo salilkadam/paperclip, main).",
  "",
  `Root folder id: ${ROOT}`,
].join("\n");

(async () => {
  const report = { root: ROOT, folders: [], files: [] };
  await ensureFile(ROOT, "README.md", README, "text/markdown");
  for (const role of ROLES) {
    const f = await ensureFolder(ROOT, role.folder);
    report.folders.push({ name: role.folder, id: f.id, mimeType: f.mimeType, created: f.created });
    await sleep(400);
    const o = await ensureFile(f.id, "OWNER.md", ownerMarkdown(role), "text/markdown");
    report.files.push({ folder: role.folder, name: "OWNER.md", id: o.id, created: o.created });
    await sleep(400);
  }
  console.log(JSON.stringify(report, null, 1));
})().catch((e) => {
  console.error("SEED-ERROR:", e.message);
  process.exit(1);
});
