#!/usr/bin/env bash
# Run the transport-parity probe from inside the bionic app pod (same egress
# path Paperclip uses). Key comes from its Secret via stdin; never printed.
set -uo pipefail
NS=bionicorg
POD=$(kubectl -n $NS get pods --no-headers | awk '/^bionic-org/ {print $1; exit}')
echo "pod: $POD"

kubectl -n $NS cp deploy/scripts/probe_transport_parity.py "$POD:/tmp/probe_transport_parity.py" -c bionic 2>/dev/null
kubectl -n $NS exec "$POD" -c bionic -- chmod 644 /tmp/probe_transport_parity.py 2>/dev/null

kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' 2>/dev/null | base64 -d \
  | kubectl -n $NS exec -i "$POD" -c bionic -- python3 /tmp/probe_transport_parity.py 2>&1 | sed 's/^/  /'

kubectl -n $NS exec "$POD" -c bionic -- rm -f /tmp/probe_transport_parity.py 2>/dev/null
