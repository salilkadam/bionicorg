import { readFileSync } from "node:fs";
// Compare state shape: cluster-internal (bypasses Cloudflare+Kong) vs public.
const key = readFileSync("/tmp/.ak", "utf8").trim();
const targets = [
  ["public-UA-Paperclip", "https://mcp.baisoln.com/gworkspace/mcp", { apikey: key, "user-agent": "Paperclip/1.0" }],
  ["public-UA-node", "https://mcp.baisoln.com/gworkspace/mcp", { apikey: key }],
];
for (const [name, base, extra] of targets) {
  try {
    const res = await fetch(base, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json, text/event-stream", ...extra },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "iso", version: "1" } } }),
    });
    const text = await res.text();
    if (res.status !== 200) { console.log(name, "-> HTTP", res.status, text.slice(0, 120)); continue; }
    const sid = res.headers.get("mcp-session-id");
    const res2 = await fetch(base, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json, text/event-stream", ...(sid ? { "mcp-session-id": sid } : {}), ...extra },
      body: JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "gw_add_account", arguments: { tenant_id: "base", account: "iso-probe", scopes: ["drive"] } } }),
    });
    const t2 = await res2.text();
    const m = t2.match(/https:\/\/accounts\.google\.com[^"\\ ]*/);
    if (!m) { console.log(name, "-> no url. head:", t2.slice(0, 160)); continue; }
    const u = new URL(m[0]);
    const st = u.searchParams.get("state");
    const b = st.split(".")[0];
    const p = JSON.parse(Buffer.from(b + "=".repeat((4 - (b.length % 4)) % 4), "base64url").toString());
    console.log(name, "-> state keys:", Object.keys(p).sort().join(","), "| pkce:", u.searchParams.has("code_challenge"));
  } catch (e) {
    console.log(name, "-> ERROR", String(e).slice(0, 120));
  }
}
