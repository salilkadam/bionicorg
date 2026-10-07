#!/usr/bin/env python3
"""Decisively test whether Google's OAuth consent screen accepts a given
redirect_uri for a client.

Read-only. Needs no client secret (Google validates redirect_uri before
authenticating the client) and prints no secrets. Discriminates on the
response BODY because the authorize endpoint answers HTTP 200 for both a
rejected URI (error page) and an accepted URI (consent/sign-in page).

Cases:
  CONTROL  a URI that is certainly not registered. Must be REFUSED; if it is
           not, the test is NON-DISCRIMINATING and nothing can be concluded.
  TARGET   the URI we want to work.
  JSON     a URI from the client JSON itself (known-good control).

Usage:
  python3 probe_google_redirect_uris.py <client-json-file> <target-redirect-uri> [client-id]
The JSON file may be the raw Google client file or the {"web":...} wrapper.
"""
import hashlib
import json
import sys
import urllib.parse
import urllib.request

AUTH = "https://accounts.google.com/o/oauth2/auth"
CONTROL = "https://definitely-not-registered.invalid.example/callback"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"


def probe(client_id, redirect_uri):
    q = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "openid email",
            "state": "probe-state",
            "prompt": "consent",
        }
    )
    req = urllib.request.Request(AUTH + "?" + q, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read(400000).decode("utf-8", "replace")
            status = r.status
            final_url = r.url
    except urllib.error.HTTPError as e:
        body = e.read(400000).decode("utf-8", "replace")
        status = e.code
        final_url = e.url or AUTH
    low = body.lower()
    # Google 302s bad requests to /signin/oauth/error (authError param) and
    # good ones to /v3/signin/identifier with redirect_uri preserved.
    if "/signin/oauth/error" in final_url or "redirect_uri_mismatch" in low:
        verdict = "REFUSED (error page: %s)" % urllib.parse.unquote(
            urllib.parse.parse_qs(urllib.parse.urlparse(final_url).query).get("authError", ["?"])[0][:60]
        )
    elif "access_blocked" in low or "access_not_configured_for_user" in low:
        verdict = "BLOCKED BEFORE URI CHECK (access/verification page)"
    elif "/signin/identifier" in final_url or "consent" in low:
        verdict = "ACCEPTED (sign-in/consent flow, callback preserved)"
    else:
        verdict = "INCONCLUSIVE"
    return status, final_url[:240], verdict, hashlib.sha256(body.encode()).hexdigest()[:12]


def main():
    json_file, target = sys.argv[1], sys.argv[2]
    d = json.load(open(json_file))
    web = d.get("web", d)
    client_id = sys.argv[3] if len(sys.argv) > 3 else web["client_id"]
    json_uri = (web.get("redirect_uris") or [""])[0]
    print("client_id:", client_id)
    print("secret sha8:", hashlib.sha256(web.get("client_secret", "").encode()).hexdigest()[:8])
    print("target     :", target)
    print()
    control_ok = None
    cases = [("CONTROL", CONTROL), ("TARGET", target)]
    if json_uri and json_uri != target:
        cases.append(("JSON", json_uri))
    for name, uri in cases:
        try:
            status, final_url, verdict, bodyhash = probe(client_id, uri)
        except Exception as exc:  # noqa: BLE001
            print("%-8s %s -> ERROR %s" % (name, uri, exc))
            continue
        print("%-8s %s\n     HTTP %s verdict=%s body-sha=%s" % (name, uri, status, verdict, bodyhash))
        if final_url and not final_url.startswith(AUTH):
            print("     redirect->", final_url)
        if name == "CONTROL":
            control_ok = verdict.startswith("REFUSED")
        # keep requests spaced out
        import time
        time.sleep(2)

    print()
    print("verdict:", "DISCRIMINATING" if control_ok else "NON-DISCRIMINATING (control not refused) — cannot conclude")
    sys.exit(0 if control_ok else 1)


main()
