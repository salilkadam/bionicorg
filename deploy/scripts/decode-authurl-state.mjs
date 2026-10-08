// Decode the OAuth state inside an auth_url and report its shape.
// Reads a JSON file passed as argv[1]: either the raw test-call HTTP response
// (nested result.content JSON string) or the direct MCP tools/call response.
import { readFileSync } from "node:fs";
const raw = readFileSync(process.argv[2], "utf8").replace(/\\\//g, "/");
let authUrl = "";
try {
  const outer = JSON.parse(raw);
  const inner = outer?.result?.content ?? outer?.result;
  const text = typeof inner === "string" ? inner : (inner?.content?.[0]?.text ?? JSON.stringify(inner));
  let payload = null;
  try { payload = JSON.parse(text); } catch {}
  authUrl = payload?.auth_url || "";
} catch {}
if (!authUrl) {
  console.log("no auth_url found; first 300 chars:", raw.slice(0, 300));
  process.exit(0);
}
const url = authUrl.split("&state=")[0] + "&state=<redacted>";
console.log("authorize host:", authUrl.startsWith("https://accounts.google.com/") ? "accounts.google.com" : "UNEXPECTED: " + authUrl.slice(0, 60));
const match = /[?&]state=([^&]+)/.exec(authUrl);
if (!match) { console.log("no state param"); process.exit(0); }
const segs = match[1].split(".");
const b64 = segs[0] + "=".repeat((4 - (segs[0].length % 4)) % 4);
let p = null;
try { p = JSON.parse(Buffer.from(b64, "base64url").toString()); } catch { console.log("state b64 decode failed"); process.exit(0); }
console.log("state keys:", Object.keys(p).sort().join(","));
console.log("tenant/account:", (p.t ?? p.tenant_id) ?? "(none)", "/", (p.a ?? p.account) ?? "(none)");
console.log("canonical:", ["t", "a", "s", "n", "exp"].every((k) => k in p), "| has sig segment:", segs.length === 2 && segs[1].length > 20);
