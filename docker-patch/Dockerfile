# syntax=docker/dockerfile:1.20
# Quick-patch image: takes docker4zerocool/bionic:71d7f47fe-fix (which exists but
# is missing the /health early-return fix in the compiled TS) and patches it in-place.
FROM docker4zerocool/bionic:71d7f47fe-fix AS base

# Copy the corrected compiled JS over the broken one
COPY docker-patch/private-hostname-guard.js /app/server/dist/middleware/private-hostname-guard.js

# This IS the fixed production image
FROM base AS production

EXPOSE 3100
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "--import", "./server/node_modules/tsx/dist/loader.mjs", "server/dist/index.js"]
