
PG="kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -x"
echo "== tool_oauth_states columns =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -t -A -c "select column_name from information_schema.columns where table_name='tool_oauth_states' order by ordinal_position;" | tr '\n' ' '
echo
echo "== latest oauth state rows (redacted values) =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "select id, created_at, status, coalesce(gateway_id::text,'-') as gw from tool_oauth_states order by created_at desc limit 4;" 2>&1 | head -12
echo "== tool_mcp_gateways =="
kubectl -n pg exec pg-ceph-7 -c postgres -- psql -d bionicorg -c "select id, coalesce(name,'-') name, coalesce(url,'-') url from tool_mcp_gateways limit 5;" 2>&1 | head -10
