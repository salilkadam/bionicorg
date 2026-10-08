### Consent URL bug found during retirement (2026-10-07)

`POST /tool-connections/:id/test-calls` for `gw_add_account` did not return a
usable `auth_url`. The initial read of the outage — that the deployed dispatch
layer *rewrote* the state into a legacy `{"tenant_id","account"}` shape — was a
misdiagnosis, corrected below after live A/B forensics.

**Verified root cause (redaction, not rewriting).** A live A/B against the
deployed build (image `40e3e904e`) and directly against
`https://mcp.baisoln.com/gworkspace/mcp` showed the upstream is clean (it
always returns the canonical `{"t","a","s","n","exp"}` state) and the gateway
returns `auth_url: "***REDACTED***"` in all three response spots (the raw
text block, `data.content[0].text`, and `data.structuredContent.auth_url`).
No legacy-state builder ever existed in server code (`git log -S 'tenant_id'`
is empty for `server/`); the "legacy state" URL seen during the incident was
stale, not a rewrite. The actual defect: `server/src/redaction.ts`
`SECRET_FIELD_NAME_PATTERN` matches the key `auth_url` (`auth` + affixes), so
`sanitizeRecord` blanked the structured field and the JSON text regexes blanked
it inside text blocks — destroying the browser-handoff artifact that
`gw_add_account` returns precisely so a human can start the connect flow.

**Fix (shipped same day).** `server/src/redaction.ts` gained a closed
consent-URL exemption: the key must be exactly `auth_url`/`authUrl` and the
value a well-formed https URL with no basic-auth userinfo and no JWT shape.
Everything else about the key keeps redacting — `auth_token`, near-miss keys
such as `refresh_auth_url`, `http://` values, and userinfo-smuggled URLs.
Regression coverage: `server/src/__tests__/redaction.test.ts` (record + text,
raw and escaped) and an end-to-end `executeTestCall` test in
`server/src/__tests__/tool-gateway.test.ts` asserting the URL survives
byte-identical in all three response spots.

**Related fix in the same change.** `server/src/services/tool-gateway.ts` no
longer silently skips a declared header credential that is missing from the
active grant (`continue` → 422
`mcp_remote_grant_credential_missing` + `missing_secret` health, never
dispatching unauthenticated). This was the real cause of the confusing Drive
errors seen through the gateway.

Scripts kept for verification: `deploy/scripts/repro-testcall-authurl-rewrite.sh`
(board-key A/B: gateway vs direct upstream, `canonical: true` expected after
the fix deploys) and `deploy/scripts/decode-authurl-state.mjs` (decodes the
base64url `state` blob). `deploy/scripts/mint-gws-consent-url.mjs` remains the
direct-mint workaround while an unfixed build is deployed.
