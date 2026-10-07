# Fast rebuild of the gworkspace MCP server image (folder-create support).
#
# Full rebuilds of multitenant-mcp-servers take ~45 min (apt layer). oauth-prm-3
# only changes two Python files on top of oauth-prm-2 (verified byte-identical
# base), so we overlay them. Both files come from merged main of
# Bionic-AI-Solutions/multitenant-mcp-servers (PR #17, commit 71bb649).
#
# Build (context = multitenant-mcp-servers repo checkout):
#   docker build --platform linux/amd64 \
#     -f paperclip/deploy/mcp/gworkspace-image/oauth-prm-3.Dockerfile \
#     -t docker4zerocool/mcp-servers-gworkspace:oauth-prm-3 \
#     multitenant-mcp-servers/
# Deploy:
#   kubectl -n mcp set image deploy/mcp-gworkspace-server \
#     gworkspace=docker.io/docker4zerocool/mcp-servers-gworkspace:oauth-prm-3
#
# The canonical (slow) path is always: build --target gworkspace from main of
# multitenant-mcp-servers; this overlay must produce an equivalent result.

FROM docker4zerocool/mcp-servers-gworkspace:oauth-prm-2
COPY src/mcp_servers/gworkspace/client.py /app/src/mcp_servers/gworkspace/client.py
COPY src/mcp_servers/gworkspace/server.py /app/src/mcp_servers/gworkspace/server.py
