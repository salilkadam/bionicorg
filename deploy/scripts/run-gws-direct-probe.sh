
# Directly probe the gworkspace MCP endpoint for gw_add_account state shape.
# Key is staged into the pod as a 0600 file, never printed.
set -euo pipefail
kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' | base64 -d > /tmp/.ak
chmod 600 /tmp/.ak
PODB=$(kubectl -n bionicorg get pods --no-headers | awk '/^bionic-org/{print $1}' | head -1)
kubectl -n bionicorg cp /tmp/.ak "$PODB:/tmp/.ak" -c bionic
kubectl -n bionicorg cp deploy/scripts/probe-gworkspace-direct.mjs "$PODB:/tmp/probe-direct.mjs" -c bionic
rm -f /tmp/.ak
kubectl -n bionicorg exec "$PODB" -c bionic -- sh -c 'node /tmp/probe-direct.mjs; rm -f /tmp/.ak /tmp/probe-direct.mjs'
