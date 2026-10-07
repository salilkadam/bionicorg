// Call gw_add_account DIRECTLY on the gworkspace MCP endpoint (bypassing the
// Paperclip gateway) and report the shape of the state inside auth_url.
// Usage: APIKEY=... node probe-gworkspace-direct.mjs
const base = process.env.GWS_URL || "https://mcp.baisoln.com/gworkspace/mcp";
import { readFileSync } from "node:fs";
const key = process.env.APIKEY || readFileSync("/tmp/.ak", "utf8").trim();

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

const init = await rpc("initialize", {
  protocolVersion: "2024-11-05",
  capabilities: {},
  clientInfo: { name: "probe", version: "1.0" },
});
const sid = init.sid;
const call = await rpc(
  "tools/call",
  { name: "gw_add_account", arguments: { tenant_id: "base", account: "probe-direct", scopes: ["drive"] } },
  sid,
);
const content = call.body?.result?.content?.[0]?.text || JSON.stringify(call.body);
let parsed = null;
try { parsed = JSON.parse(content); } catch {}
const url = parsed?.auth_url || "";
console.log("http status:", call.status);
console.log("auth_url host:", url ? new URL(url).searchParams.get("client_id")?.split(".")[0] : "(none)");
const state = new URL(url).searchParams.get("state");
const b64 = state.split(".")[0];
const payload = JSON.parse(Buffer.from(b64 + "=".repeat((4 - (b64.length % 4)) % 4), "base64url").toString());
console.log("state keys:", Object.keys(payload).sort().join(","));
console.log("state tenant/account:", payload.t ?? payload.tenant_id, "/", payload.a ?? payload.account);
console.log("has sig segment:", state.split(".").length === 2 && state.split(".")[1].length > 20);
console.log("has exp:", "exp" in payload);
