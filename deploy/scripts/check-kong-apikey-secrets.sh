#!/usr/bin/env bash
# Inspect the Kong apikey secrets (field names + which consumer + Vault source)
# without printing key material.
set -uo pipefail
for NAME in mcp-shared-apikey mcp-admin-apikey mcp-cursor-apikey mcp-typical-app-apikey; do
  echo "== secret $NAME =="
  kubectl -n mcp get secret "$NAME" -o json > "/tmp/scratchpad/secret-$NAME.json" 2>/dev/null || { echo "  missing"; continue; }
  python3 - "/tmp/scratchpad/secret-$NAME.json" "$NAME" <<'PY'
import json, sys, base64, hashlib
path, name = sys.argv[1], sys.argv[2]
d = json.load(open(path))
labels = d["metadata"].get("labels", {})
print("  labels:", {k: v for k, v in labels.items() if "konghq" in k})
for k, v in (d.get("data") or {}).items():
    raw = base64.b64decode(v)
    print(f"  field {k}: len={len(raw)} sha8={hashlib.sha256(raw).hexdigest()[:8]}")
PY
  echo "  vault source:"
  kubectl -n mcp get externalsecret "$NAME" -o jsonpath='{.spec.data[*].remoteRef.key}{" / "}{.spec.data[*].remoteRef.property}{"\n"}' 2>/dev/null | sed 's/^/    /'
done
