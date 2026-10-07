#!/usr/bin/env bash
# Locate a k8s Secret carrying GOOGLE_AUTH_TOKEN (bionic ESO synced from Vault
# t6-apps/bionic-org/config) and save the JSON to a local file for the probe.
# Does not print the value.
set -euo pipefail
KUBECTL="${KUBECTL:-kubectl}"
OUT=/tmp/gcli-new.json
for NSV in bionicorg mcp; do
  while IFS= read -r S; do
    test -n "$S" || continue
    VAL="$($KUBECTL -n "$NSV" get secret "$S" -o jsonpath='{.data.GOOGLE_AUTH_TOKEN}' 2>/dev/null || true)"
    if [ -n "$VAL" ]; then
      echo "$VAL" | base64 -d > "$OUT" 2>/dev/null || true
      if [ -s "$OUT" ]; then
        echo "found secret $NSV/$S, bytes: $(wc -c < "$OUT")"
        exit 0
      fi
    fi
  done < <($KUBECTL -n "$NSV" get secrets -o name 2>/dev/null | sed 's#secret/##')
done
echo "no GOOGLE_AUTH_TOKEN secret found"; exit 1
