"""Check whether each Reliora agent's instructions contain the Drive block.

Reads the board token from /tmp/.bt and "id|name" lines from argv[1].
"""
import json
import sys
import urllib.request

with open("/tmp/.bt") as fh:
    token = fh.read().strip()

rows = []
with open(sys.argv[1]) as fh:
    for line in fh:
        line = line.strip()
        if "|" in line:
            agent_id, name = line.split("|", 1)
            rows.append((agent_id.strip(), name.strip()))


def get(path):
    req = urllib.request.Request(f"http://localhost:3100/api{path}")
    req.add_header("authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, json.load(resp)
    except Exception as err:  # noqa: BLE001
        return 0, {"error": f"{type(err).__name__}: {err}"}


for agent_id, name in rows:
    s_b, bundle = get(f"/agents/{agent_id}/instructions-bundle")
    entry = bundle.get("entryFile") or "AGENTS.md"
    s_f, f = get(
        f"/agents/{agent_id}/instructions-bundle/file?path={entry}"
    )
    content = f.get("content") or ""
    if "salil-bionicaisolutions" in content:
        tag = "HAS drive block"
    elif not content:
        tag = f"no entry file (http {s_f})"
    else:
        tag = "NO drive block"
    print(f"  {agent_id[:8]}  {name[:24]:<24}  entry={entry:<12} {tag}  len={len(content)}")
