#!/usr/bin/env python3
"""Step 2b: build a FULL kv payload (all existing properties, tenant "base"
switched to the new Google client) for `vault kv put ... @file`.
Reads /tmp/mcp-cfg.json and /tmp/nt.txt; writes /tmp/payload.json (0600).
Prints nothing secret."""
import json
import os

cfg = json.load(open("/tmp/mcp-cfg.json"))["data"]["data"]
tenants_value = open("/tmp/nt.txt").read().strip()
# sanity: value is the patched bare map with new client in base
t = json.loads(tenants_value)["base"]
assert t["client_id"].startswith("382016492812-"), "payload not patched!"
cfg["gworkspace_tenants_json"] = tenants_value
with open("/tmp/payload.json", "w") as f:
    json.dump(cfg, f)
os.chmod("/tmp/payload.json", 0o600)
print("payload keys:", len(cfg), "bytes:", os.path.getsize("/tmp/payload.json"))
