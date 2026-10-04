#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build-and-push.sh — Build Bionic Docker image and push to registry
#
# Usage:
#   ./deploy/scripts/build-and-push.sh [TAG]
#
# Defaults to git short SHA if no TAG is provided.
# Requires: docker, git
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")/../.."  # repo root (script lives in deploy/scripts/)

TAG="${1:-$(git rev-parse --short HEAD)}"
IMAGE="docker4zerocool/bionic"
FULL="${IMAGE}:${TAG}"

echo "=== Building Bionic image ==="
echo "  Image : ${FULL}"
echo "  Tag   : ${TAG}"
echo ""

docker build -t "${FULL}" . --target production

echo ""
echo "=== Pushing image ==="
docker push "${FULL}"

echo ""
echo "=== Done ==="
echo "  Image ready: ${FULL}"
