#!/usr/bin/env bash
# Wrapper: copy the redirect-URI probe into the gworkspace pod (which holds
# GOOGLE_AUTH_TOKEN in its environment) and run it there.
# Safe: read-only, no secrets in output.
set -euo pipefail
KUBECTL="${KUBECTL:-kubectl}"
NS="${MCP_NS:-mcp}"
POD="$($KUBECTL -n "$NS" get pods --no-headers 2>/dev/null | awk '/^mcp-gworkspace-server/{print $1}' | head -1)"
test -n "$POD" || { echo "gworkspace pod not found"; exit 1; }
echo "pod: $POD"
"$KUBECTL" -n "$NS" cp "$(dirname "$0")/probe_google_redirect_uris.py" "$POD:/tmp/probe_google_redirect_uris.py"
"$KUBECTL" -n "$NS" exec "$POD" -c gworkspace -- python3 /tmp/probe_google_redirect_uris.py
