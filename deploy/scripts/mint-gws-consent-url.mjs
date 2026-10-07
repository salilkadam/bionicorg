import { readFileSync } from "node:fs";
// Generate the CANONICAL gw_add_account consent URL directly from the
// gworkspace server (bypasses the Paperclip test-calls rewrite), for the
// account passed as argv[1]. Prints only the URL.
const key = readFileSync("/tmp/.ak", "utf8").trim();
const account = process.argv[2] || "bionicorg";
const base = "https://mcp.baisoln.com/gworkspace/mcp";
async function rpc(method, params, sessionId) {
  const res = await fetch(base, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json, text/event-stream", apikey: key, ...(sessionId ? { "mcp-session-id": sessionId } : {}) },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const text = await res.text();
  const dataLine = text.split("\n").find((l) => l.startsWith("data:"));
  return { sid: res.headers.get("mcp-session-id"), body: (() => { try { return JSON.parse(dataLine ? dataLine.slice(5) : text); } catch { return null; } })() };
}
const init = await rpc("initialize", { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "consent", version: "1" } });
const call = await rpc("tools/call", { name: "gw_add_account", arguments: { tenant_id: "base", account, scopes: ["drive"] } }, init.sid);
const t = call.body?.result?.content?.[0]?.text || "";
const m = t.match(/https:\/\/accounts\.google\.com[^"\\]*/);
if (!m) { console.error("no url"); process.exit(1); }
console.log(m[0]);
