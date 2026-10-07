#!/usr/bin/env bash
# Stage the shared MCP apikey and run the Drive-list probe inside the bionic pod.
# Usage: run-gws-drive-list-probe.sh [ROOT_FOLDER_ID]
set -euo pipefail
ROOT_ARG="${1:-}"
kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' | base64 -d > /tmp/.ak
chmod 600 /tmp/.ak
PODB=$(kubectl -n bionicorg get pods --no-headers | awk '/^bionic-org/{print $1}' | head -1)
kubectl -n bionicorg cp /tmp/.ak "$PODB:/tmp/.ak" -c bionic
kubectl -n bionicorg cp deploy/scripts/probe-gws-drive-list.mjs "$PODB:/tmp/probe-drive-list.mjs" -c bionic
rm -f /tmp/.ak
kubectl -n bionicorg exec "$PODB" -c bionic -- sh -c "node /tmp/probe-drive-list.mjs $ROOT_ARG; rm -f /tmp/.ak /tmp/probe-drive-list.mjs"
