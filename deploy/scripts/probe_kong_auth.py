"""Probe the gworkspace MCP endpoint auth paths.

Reads a candidate Kong apikey from stdin. Never prints the key.
"""
import json
import sys
import urllib.error
import urllib.request

KEY = sys.stdin.read().strip()
print("key received, length:", len(KEY))

BODY = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}).encode()
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/129.0 Safari/537.36"
)
KONG = "https://mcp.baisoln.com/gworkspace/mcp"


def probe(label, url, headers):
    req = urllib.request.Request(url, data=BODY, method="POST")
    req.add_header("content-type", "application/json")
    req.add_header("accept", "application/json, text/event-stream")
    req.add_header("user-agent", UA)
    for name, value in headers.items():
        req.add_header(name, value)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read(120).decode("utf-8", "replace")
            print(f"{label}: http={resp.status} body[:120]={body}")
    except urllib.error.HTTPError as err:
        body = err.read(200).decode("utf-8", "replace")
        print(f"{label}: http={err.code} body[:200]={body}")
    except Exception as err:  # noqa: BLE001
        print(f"{label}: {type(err).__name__}: {err}")


if KEY:
    probe("kong + apikey header", KONG, {"apikey": KEY})
    probe("kong + X-API-Key header", KONG, {"X-API-Key": KEY})
    probe("kong + wrong key", KONG, {"apikey": "0" * len(KEY)})
else:
    print("no key on stdin; skipping credentialed probes")
