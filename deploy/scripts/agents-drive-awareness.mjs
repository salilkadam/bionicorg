#!/usr/bin/env node
/**
 * Make bionic-org agents aware of the Loc-Google Workspace artifact space.
 *
 * Appends (idempotently) a delimited "Google Drive artifact space" section to
 * each org agent's entry AGENTS.md via the Paperclip instructions-bundle API.
 * Re-running replaces the section in place (marker-delimited).
 *
 * Usage (inside the app pod; token is the FIRST stdin line):
 *   printf '%s\n' "$TOKEN" | cat - deploy/scripts/agents-drive-awareness.mjs | \
 *     kubectl -n bionicorg exec -i deploy/bionic-org -c bionic -- \
 *     sh -c 'read T; export BIONIC_BOARD_TOKEN=$T; exec node -'
 */

const API = process.env.BIONIC_API || "http://localhost:3100/api";

const TENANT = "base";
const ACCOUNT = "salil-bionicaisolutions";
const ROOT = "1MmJAx3Rkag90KSSlFISiVvkuWwvO38dK"; // AI Team
const SHARED = "1X3mLZ0IP1pJDJtMm5WZwoAzBb_qoh5dz"; // _shared
const BEGIN = "<!-- BEGIN bionic-org:google-drive-artifacts -->";
const END = "<!-- END bionic-org:google-drive-artifacts -->";

// Reliora Inc (62d63984-df6c-49be-981c-1273f68a451c) active roster.
// Folder ids from deploy/README.md "Google Drive artifact space".
const AGENTS = [
  { id: "73cae9f9-b419-48f1-b395-7e7e8c41048d", role: "CEO", folder: "1XGRgQDdZZOeDwVU9omlg6bNE5eEaZFeC" },
  { id: "70499d70-c8de-4a11-b75f-70596e18e7e2", role: "COO", folder: "1-UGS4ohfHND3mi1LBIX4eJUln6mxw2ey" },
  { id: "84d36e9e-e1f3-40d2-b36c-3c52140039a5", role: "CMO", folder: "10Ncj5HLJW0NdX0asahftmL1yPmO0W0P3" },
  { id: "fb6429f4-d521-4034-ad56-dc3f951711bf", role: "CIO", folder: "1AZI8sLSO5hjx9B9D2HEfEfYysRg4kdCo" },
  { id: "9ca37669-bd76-4389-97b5-b1c677fedac2", role: "CLO", folder: "1APCrCwB98knSn7GYjUXpURlhuVRISmZb" },
  { id: "80214764-0c4d-43d5-b495-4cc8eee1b0d0", role: "Project Manager", folder: "1RPveSfN6e8zCmnJwNBk5o3G9JVooAimM" },
  { id: "6c3d9ec8-604d-4621-98b3-761931c72225", role: "Sr. Engineer", folder: "16QRpoyGqlaVFTosGBRfoiBg0dkMzY0Y5" },
];

function section(role, folder) {
  return [
    BEGIN,
    "## Google Drive artifact space (Loc-Google Workspace)",
    "",
    "Final documents (reports, plans, memos, legal docs, marketing copy,",
    "templates, company material) are delivered to the org Google Drive space",
    '"AI Team" using the **Loc-Google Workspace** MCP tools on every run.',
    `Always use \`tenant_id: "${TENANT}"\` and \`account: "${ACCOUNT}"\`.`,
    "",
    `- **Your folder (you own its contents):** "${role}" → folder_id \`${folder}\``,
    `- **Cross-role space:** "_shared" → folder_id \`${SHARED}\` (use a`,
    '  "templates" subfolder there for reusable templates other roles need).',
    "",
    "Saving a document:",
    "",
    "```",
    "gw_create_file { tenant_id, account, name: \"YYYY-MM-DD-<slug>.md\",",
    `  content: <markdown>, mime_type: "text/markdown", folder_id: "${folder}" }`,
    "```",
    "",
    "- Always pass your own `folder_id`. Never drop files at the AI Team root",
    `  (\`${ROOT}\`) or in another role's folder.`,
    '- Organize with `gw_create_folder { tenant_id, account, name, folder_id }`',
    "  inside your own folder only.",
    "- Find files: `gw_list_files { …, query: \"'<folder_id>' in parents and",
    "  trashed=false\" }` (there is no folder_id argument on list). Read file",
    "  content with `gw_get_file { …, file_id, download: true }`.",
    "- The `OWNER.md` in your folder is the authoritative ownership record;",
    "  never delete or overwrite it. Drive `owner` fields show the linked",
    "  operator account; ownership is expressed by folder placement.",
    "- In issue final comments, link the delivered Drive file's `webViewLink`.",
    END,
  ].join("\n");
}

async function api(path, init = {}) {
  const res = await fetch(API + path, {
    ...init,
    headers: {
      Authorization: "Bearer " + process.env.BIONIC_BOARD_TOKEN,
      "Content-Type": "application/json",
      ...(init.headers || {}),
    },
  });
  const body = await res.text();
  let json = null;
  try { json = JSON.parse(body); } catch {}
  if (!res.ok) throw new Error(path + " -> " + res.status + " " + body.slice(0, 200));
  return json;
}

(async () => {
  if (!process.env.BIONIC_BOARD_TOKEN) throw new Error("no board token (set BIONIC_BOARD_TOKEN)");
  const report = [];
  for (const a of AGENTS) {
    const q = encodeURIComponent("AGENTS.md");
    const cur = await api(`/agents/${a.id}/instructions-bundle/file?path=${q}`);
    let content = cur.content ?? "";
    const add = section(a.role, a.folder);
    let next;
    if (content.includes(BEGIN)) {
      next = content.replace(new RegExp(`${BEGIN}[\\s\\S]*?${END}`), add);
    } else {
      next = content.trimEnd() + "\n\n" + add + "\n";
    }
    // Remove the earlier unmarked legacy block so exactly one Drive section
    // remains (this marker-delimited one).
    next = next.replace(
      new RegExp(`\\n*## Google Drive artifact publication \\(mandatory\\)[\\s\\S]*?(?=${BEGIN})`, "g"),
      "\n\n",
    );
    if (next === content) { report.push({ role: a.role, result: "unchanged" }); continue; }
    await api(`/agents/${a.id}/instructions-bundle/file`, {
      method: "PUT",
      body: JSON.stringify({ path: "AGENTS.md", content: next, baseHash: cur.contentHash ?? null }),
    });
    report.push({ role: a.role, result: "updated", chars: next.length - content.length });
  }
  console.log(JSON.stringify(report, null, 1));
})().catch((e) => { console.error("ERR:", e.message); process.exit(1); });
