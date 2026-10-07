// Probe the gworkspace MCP endpoint directly with account=bionicorg to prove
// the Drive API works after the new GCP project enablement, and to discover
// why the AI Team root folder reports "File not found".
// Usage: APIKEY=... node probe-gws-drive-list.mjs [ROOT_FOLDER_ID]
const base = process.env.GWS_URL || "https://mcp.baisoln.com/gworkspace/mcp";
import { readFileSync } from "node:fs";
const key = process.env.APIKEY || readFileSync("/tmp/.ak", "utf8").trim();
const root = process.argv[2] || "";

async function rpc(method, params, sessionId) {
  const res = await fetch(base, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      accept: "application/json, text/event-stream",
      apikey: key,
      ...(sessionId ? { "mcp-session-id": sessionId } : {}),
    },
    body: JSON.stringify({ jsonrpc: "2.0", id: Math.floor(Math.random() * 1e6), method, params }),
  });
  const sid = res.headers.get("mcp-session-id");
  const text = await res.text();
  let body = null;
  const dataLine = text.split("\n").find((l) => l.startsWith("data:"));
  try { body = JSON.parse(dataLine ? dataLine.slice(5) : text); } catch {}
  return { status: res.status, sid, body };
}

const textOf = (call) => call.body?.result?.content?.map((c) => c.text).join("\n") || JSON.stringify(call.body);

const init = await rpc("initialize", {
  protocolVersion: "2024-11-05",
  capabilities: {},
  clientInfo: { name: "probe", version: "1.0" },
});
const sid = init.sid;

// 1. Schema of gw_list_files
const list = await rpc("tools/list", {}, sid);
const tools = list.body?.result?.tools || [];
const lf = tools.find((t) => t.name === "gw_list_files");
console.log("== gw_list_files schema ==");
console.log(lf ? JSON.stringify(lf.inputSchema?.properties ? Object.keys(lf.inputSchema.properties) : lf.inputSchema) : "(not found)");

// 2. Root listing (no folder argument) with bionicorg
const a = await rpc("tools/call", { name: "gw_list_files", arguments: { tenant_id: "base", account: "bionicorg" } }, sid);
console.log("\n== call A: no args (root) ==");
console.log(textOf(a).slice(0, 900).replace(/\\\//g, "/"));

// 3. Explicit folder_id with the AI Team root
if (root) {
  const b = await rpc("tools/call", { name: "gw_list_files", arguments: { tenant_id: "base", account: "bionicorg", folder_id: root } }, sid);
  console.log("\n== call B: folder_id=" + root + " ==");
  console.log(textOf(b).slice(0, 900).replace(/\\\//g, "/"));
}
