import { readFileSync } from "node:fs";
const base = "https://mcp.baisoln.com/gworkspace/mcp";
const key = readFileSync("/tmp/.ak", "utf8").trim();
async function rpc(method, params, sessionId) {
  const res = await fetch(base, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json, text/event-stream", apikey: key, ...(sessionId ? { "mcp-session-id": sessionId } : {}) },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const text = await res.text();
  const dataLine = text.split("\n").find((l) => l.startsWith("data:"));
  return { sid: res.headers.get("mcp-session-id"), body: (() => { try { return JSON.parse(dataLine ? dataLine.slice(5) : text); } catch { return null; } })(), server: res.headers.get("server") };
}
const init = await rpc("initialize", { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "fp", version: "1" } });
const call = await rpc("tools/call", { name: "gw_list_accounts", arguments: { tenant_id: "base" } }, init.sid);
const t = call.body?.result?.content?.[0]?.text || JSON.stringify(call.body);
try {
  const p = JSON.parse(t);
  const accts = (p.accounts || []).map((a) => a.alias || a.account).sort();
  console.log("server header:", call.server);
  console.log("accounts:", JSON.stringify(accts));
} catch { console.log("raw:", t.slice(0, 400)); }
