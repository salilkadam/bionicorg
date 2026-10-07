#!/usr/bin/env bash
# Empirically determine where the gworkspace 401 comes from.
#   Test 1: through Kong (mcp.baisoln.com) with the real apikey header.
#   Test 2: direct to the cluster service with a spoofed Kong consumer header
#           (proves whether the app middleware accepts Kong's header contract).
# The key is read from the K8s secret and piped to stdin; it is NEVER printed.
set -uo pipefail
P=$(kubectl -n mcp get pods --no-headers | awk '/mcp-gworkspace-server/ {print $1; exit}')

kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' 2>/dev/null | base64 -d \
  | kubectl -n mcp exec -i "$P" -c gworkspace -- python3 - > /tmp/scratchpad/konglink.out 2>&1 <<'PY'
import json, sys, urllib.request, urllib.error

key = sys.stdin.read().strip()
print("key received, length:", len(key))

BODY = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}).encode()
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Safari/537.36"


def probe(label, url, headers):
    req = urllib.request.Request(url, data=BODY, method="POST")
    req.add_header("content-type", "application/json")
    req.add_header("accept", "application/json, text/event-stream")
    req.add_header("user-agent", UA)
    for h, v in headers.items():
        req.add_header(h, v)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            print(f"{label}: http={r.status} body[:120]={r.read(120).decode('utf-8','replace')}")
    except urllib.error.HTTPError as e:
        print(f"{label}: http={e.code} body[:200]={e.read(200).decode('utf-8','replace')}")
    except Exception as e:
        print(f"{label}: {type(e).__name__}: {e}")


KONG = "https://mcp.baisoln.com/gworkspace/mcp"
INTERNAL = "http://mcp-gworkspace-server.mcp.svc.cluster.local:8015/mcp"

probe("1 kong+apikey", KONG, {"apikey": key})
probe("2 kong+X-API-Key", KONG, {"X-API-Key": key})
probe("3 kong+bad key", KONG, {"apikey": "0" * len(key)})
probe("4 direct+spoofed consumer", INTERNAL, {"x-consumer-username": "mcp-shared"})
probe("5 direct+bare", INTERNAL, {})
PY
cat /tmp/scratchpad/konglink.out
