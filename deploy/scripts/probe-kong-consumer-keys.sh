#!/usr/bin/env bash
# Try each Kong consumer's key against the gworkspace route to find out whether
# Kong apikey auth works at all here, or only this consumer's key is unknown.
# Keys are read from their Secrets and piped to the probe; never printed.
set -uo pipefail
P=$(kubectl -n mcp get pods --no-headers | awk '/mcp-gworkspace-server/ {print $1; exit}')

kubectl -n mcp cp deploy/scripts/probe_kong_auth.py "$P:/tmp/probe_kong_auth.py" -c gworkspace 2>/dev/null

for CONS in mcp-shared mcp-cursor mcp-admin mcp-typical-app; do
  echo "== consumer: $CONS =="
  kubectl -n mcp get secret "${CONS}-apikey" -o jsonpath='{.data.key}' 2>/dev/null | base64 -d \
    | kubectl -n mcp exec -i "$P" -c gworkspace -- python3 /tmp/probe_kong_auth.py 2>&1 \
    | sed 's/^/  /'
done

echo "== credential secret labels (how KIC links secret -> consumer) =="
kubectl -n mcp get secret mcp-shared-apikey -o json 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print(json.dumps(d["metadata"].get("labels",{}),indent=1));print("annotations:",json.dumps(d["metadata"].get("annotations",{})))'
echo "== kongconsumer mcp-shared =="
kubectl -n mcp get kongconsumers.configuration.konghq.com mcp-shared -o json 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print("spec:",json.dumps(d.get("spec",{})));print("labels:",json.dumps(d["metadata"].get("labels",{})));print("anns:",json.dumps(d["metadata"].get("annotations",{})))'
