#!/usr/bin/env bash
# Look for the Google-side failure signature on the OAuth path:
#  - referrer/reason from accounts.google.com (error=access_denied / redirect_uri_mismatch / htf=1)
#  - callback hits with query keys (a real Google redirect always has ?code or ?error)
#  - gworkspace oauth-callback lines
set -uo pipefail

echo "== nginx: requests touching /gworkspace/oauth (last 50) =="
for POD in $(kubectl -n ingress get pods --no-headers 2>/dev/null | awk '{print $1}'); do
  kubectl -n ingress logs "$POD" --since=6h 2>/dev/null | grep -a "/gworkspace/oauth" | tail -n 50
done > /tmp/scratchpad/nginx-oauth.out 2>&1
wc -l < /tmp/scratchpad/nginx-oauth.out | sed 's/^/lines: /'
tail -n 15 /tmp/scratchpad/nginx-oauth.out

echo
echo "== gworkspace: every oauth-callback line since 6h (with query keys) =="
P=$(kubectl -n mcp get pods --no-headers | awk '/mcp-gworkspace-server/ {print $1; exit}')
kubectl -n mcp logs "$P" -c gworkspace --since=6h 2>&1 | grep -aE "oauth-callback|redirect_uri|access_denied|mismatch" | tail -n 40 > /tmp/scratchpad/gws-cb.out
wc -l < /tmp/scratchpad/gws-cb.out | sed 's/^/lines: /'
tail -n 25 /tmp/scratchpad/gws-cb.out
