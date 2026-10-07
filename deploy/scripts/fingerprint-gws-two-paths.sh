
set -euo pipefail
kubectl -n mcp get secret mcp-shared-apikey -o jsonpath='{.data.key}' | base64 -d > /tmp/.ak
chmod 600 /tmp/.ak
PODB=$(kubectl -n bionicorg get pods --no-headers | awk '/^bionic-org/{print $1}' | head -1)
kubectl -n bionicorg cp /tmp/.ak "$PODB:/tmp/.ak" -c bionic
kubectl -n bionicorg cp deploy/scripts/probe-gws-accounts-direct.mjs "$PODB:/tmp/fp.mjs" -c bionic
rm -f /tmp/.ak
echo "== DIRECT via mcp.baisoln.com (from bionic pod) =="
kubectl -n bionicorg exec "$PODB" -c bionic -- sh -c 'node /tmp/fp.mjs; rm -f /tmp/.ak /tmp/fp.mjs'
echo "== gworkspace pod's redis truth =="
PODG=$(kubectl -n mcp get pods --no-headers | awk '/^mcp-gworkspace-server/{print $1}' | head -1)
kubectl -n mcp exec "$PODG" -c gworkspace -- python3 -c "
import redis, os
r = redis.Redis(host=os.environ['REDIS_HOST'], port=int(os.environ['REDIS_PORT']), db=int(os.environ.get('REDIS_DB','8')))
print('redis:', os.environ['REDIS_HOST'], 'db', os.environ.get('REDIS_DB','8'))
h = r.hgetall('mcp:gworkspace:accounts:base')
print('accounts:', sorted(k.decode() for k in h))
"
