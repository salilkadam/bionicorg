"""Delete one Drive file using the tenant's stored refresh token.

Runs inside the gworkspace pod, where the Redis account hash and the tenant
OAuth client config are both available. Prints only status codes; no
credentials are echoed.
"""
import json
import os
import redis
import urllib.error
import urllib.parse
import urllib.request

FILE_ID = os.environ.get("DELETE_FILE_ID", "")
ACCOUNT = "salil-bionicaisolutions"

if not FILE_ID:
    raise SystemExit("DELETE_FILE_ID not set")

r = redis.Redis(
    host=os.environ.get("REDIS_HOST") or "redis",
    port=int(os.environ.get("REDIS_PORT") or 6379),
    db=int(os.environ.get("REDIS_DB") or 0),
    decode_responses=True,
)
raw = r.hget("mcp:gworkspace:accounts:base", ACCOUNT)
if not raw:
    raise SystemExit("account not found in redis")
acct = json.loads(raw)

tenants = json.load(open("/etc/mcp/tenants.json"))
tenant = tenants["base"]

token_url = "https://oauth2.googleapis.com/token"
data = urllib.parse.urlencode(
    {
        "client_id": tenant["client_id"],
        "client_secret": tenant["client_secret"],
        "refresh_token": acct["refresh_token"],
        "grant_type": "refresh_token",
    }
).encode()

try:
    with urllib.request.urlopen(
        urllib.request.Request(token_url, data=data, method="POST"), timeout=30
    ) as resp:
        access = json.load(resp)["access_token"]
    print("token exchange: ok")
except urllib.error.HTTPError as err:
    print(f"token exchange: http={err.code} body[:160]={err.read(160).decode('utf-8','replace')}")
    raise SystemExit(1)

req = urllib.request.Request(
    f"https://www.googleapis.com/drive/v3/files/{FILE_ID}", method="DELETE"
)
req.add_header("authorization", f"Bearer {access}")
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        print(f"delete: http={resp.status} (204 = trashed)")
except urllib.error.HTTPError as err:
    print(f"delete: http={err.code} body[:200]={err.read(200).decode('utf-8','replace')}")
