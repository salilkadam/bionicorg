"""Reproduce Paperclip's outbound MCP request as closely as possible.

Reads the apikey from stdin (never printed). Compares transports so we can see
whether the 401 is caused by the credential, the User-Agent, or Cloudflare.
"""
import json
import os
import sys

KEY = sys.stdin.read().strip()
URL = "https://mcp.baisoln.com/gworkspace/mcp"
BODY = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/list"})

print("key length:", len(KEY))

import urllib.error
import urllib.request


def urllib_probe(label, headers):
    req = urllib.request.Request(URL, data=BODY.encode(), method="POST")
    for name, value in headers.items():
        req.add_header(name, value)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"{label}: http={resp.status} bytes={len(resp.read())}")
    except urllib.error.HTTPError as err:
        print(f"{label}: http={err.code} bytes={len(err.read())}")
    except Exception as err:  # noqa: BLE001
        print(f"{label}: {type(err).__name__}: {err}")


base = {
    "content-type": "application/json",
    "accept": "application/json, text/event-stream",
}

# Same header set Paperclip sends, but with undici's default (no) UA.
urllib_probe("no-UA + apikey (undici-like)", {**base, "apikey": KEY})
urllib_probe(
    "node UA + apikey",
    {**base, "User-Agent": "node", "apikey": KEY},
)
urllib_probe(
    "browser UA + apikey",
    {
        **base,
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/129.0 Safari/537.36",
        "apikey": KEY,
    },
)
urllib_probe("no-UA, no credential", dict(base))

# Now with Node's own fetch, if we are inside the app container.
try:
    import subprocess

    node_src = """
const key = process.env.__K;
fetch("https://mcp.baisoln.com/gworkspace/mcp", {
  method: "POST",
  headers: {
    "content-type": "application/json",
    accept: "application/json, text/event-stream",
    apikey: key,
  },
  body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
})
  .then(async (r) => {
    const b = await r.text();
    console.log(`node-fetch: http=${r.status} bytes=${b.length}`);
  })
  .catch((e) => console.log("node-fetch: error", e.name, String(e).slice(0, 160)));
"""
    proc = subprocess.run(
        ["node", "-e", node_src],
        capture_output=True,
        text=True,
        timeout=60,
        env={**os.environ, "__K": KEY},
    )
    print(proc.stdout.strip() or "(node produced no stdout)")
    if proc.stderr.strip():
        print("node stderr:", proc.stderr.strip()[:200])
except FileNotFoundError:
    print("node not present in this container; skipped node-fetch probe")
