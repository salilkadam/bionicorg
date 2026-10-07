#!/usr/bin/env bash
# Force ESO reconcile of bionic-org-secrets and report whether google_auth_token changed.
set -uo pipefail
BEFORE=$(kubectl -n bionicorg get secret bionic-org-secrets -o jsonpath='{.data.google_auth_token}' | base64 -d | sha256sum | cut -c1-8)
echo "secret sha8 before: $BEFORE"
NOW=$(date +%s)
kubectl -n bionicorg annotate externalsecret bionic-org-secrets force-sync="$NOW" --overwrite >/dev/null
sleep 25
AFTER=$(kubectl -n bionicorg get secret bionic-org-secrets -o jsonpath='{.data.google_auth_token}' | base64 -d | sha256sum | cut -c1-8)
echo "secret sha8 after : $AFTER"
ENVD=$(kubectl -n bionicorg exec deploy/bionic-org -c bionic -- sh -c 'printf %s "$GOOGLE_AUTH_TOKEN" | sha256sum | cut -c1-8' 2>/dev/null | tail -1)
echo "pod env sha8      : $ENVD"
if [ "$BEFORE" = "$AFTER" ]; then echo "VERDICT: Vault's current value == what ESO already had ($([ "$AFTER" = "$ENVD" ] && echo 'and pod env matches — no restart needed' || echo 'pod env DIFFERS — restart needed'))"; else echo "VERDICT: value CHANGED on force-sync (pod env now stale — restart needed)"; fi
kubectl -n bionicorg get externalsecret bionic-org-secrets -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.lastTransitionTime} {.message}{"\n"}{end}' 2>&1 | head -2
