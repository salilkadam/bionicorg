#!/usr/bin/env python3
"""Step 2 of the tenant-client switch: rewrite tenant "base" in the gworkspace
tenants JSON to use the NEW Google OAuth client, preserving every other field
(including state_signing_key). Prints hashes only.

Reads:  /tmp/mcp-cfg.json  (vault kv get -format=json output)
        /tmp/gcli-new.json (new Google client JSON, possibly {"web":...})
Writes: /tmp/nt.txt        (single-line new tenants JSON value for Vault)
"""
import base64
import hashlib
import json
import sys

CFG = "/tmp/mcp-cfg.json"
NEW = "/tmp/gcli-new.json"
OUT = "/tmp/nt.txt"
TARGET_REDIRECT = "https://mcp.baisoln.com/gworkspace/oauth/callback"


def h(v):
    return hashlib.sha256(str(v).encode()).hexdigest()[:8] if v else "-"


cfg = json.load(open(CFG))["data"]["data"]
raw = cfg["gworkspace_tenants_json"]
b64_form = not raw.strip().startswith("{")
tenants = json.loads(base64.b64decode(raw)) if b64_form else json.loads(raw)
if "tenants" in tenants and isinstance(tenants["tenants"], dict):
    tenants = tenants["tenants"]

new = json.load(open(NEW))
new = new.get("web", new)

t = tenants.get("base")
if not t:
    sys.exit("tenant base missing")
print("BEFORE base: client_id=%s secret-sha8=%s state-sha8=%s redirect=%s"
      % (t.get("client_id"), h(t.get("client_secret")), h(t.get("state_signing_key")), t.get("redirect_uri")))

old_tenant = dict(t)
t["client_id"] = new["client_id"]
t["client_secret"] = new["client_secret"]
t["redirect_uri"] = TARGET_REDIRECT

value = tenants  # bare map
if "base" not in value:
    sys.exit("sanity: base lost")
s = json.dumps(value, separators=(",", ":"), sort_keys=False)
if b64_form:
    s = base64.b64encode(s.encode()).decode()
open(OUT, "w").write(s)

tt = json.loads(json.dumps(t))
print("AFTER  base: client_id=%s secret-sha8=%s state-sha8=%s redirect=%s"
      % (tt["client_id"], h(tt["client_secret"]), h(tt.get("state_signing_key")), tt["redirect_uri"]))
print("state_signing_key preserved:", h(old_tenant.get("state_signing_key")) == h(tt.get("state_signing_key")))
print("value form: %s | bytes: %d" % ("base64" if b64_form else "plain-json", len(s)))
