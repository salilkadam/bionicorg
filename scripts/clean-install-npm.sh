#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PC_INSTALL_DRIVER="${PC_INSTALL_DRIVER:-source}"

PC_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bionic-clean-install.XXXXXX")"
PC_HOME="$PC_TEST_ROOT/home"
PC_CACHE="$PC_TEST_ROOT/npm-cache"
mkdir -p "$PC_HOME" "$PC_CACHE"
trap 'rm -rf "$PC_TEST_ROOT"' EXIT

export HOME="$PC_HOME"
export BIONIC_HOME="$PC_HOME/.bionic"
export npm_config_cache="$PC_CACHE"
export npm_config_userconfig="$PC_HOME/.npmrc"
export PATH="$PC_HOME/.local/bin:$PATH"

if [ "$PC_INSTALL_DRIVER" = "published" ]; then
  (cd "$PC_TEST_ROOT" && npx --yes --registry https://registry.npmjs.org bionicai install)
else
  (cd "$REPO_ROOT" && pnpm bionicai install --yes)
fi

test -x "$PC_HOME/.local/bin/bionicai"
test -L "$BIONIC_HOME/cli/current"
test -f "$BIONIC_HOME/cli/install.json"
bionicai --version

mkdir -p "$BIONIC_HOME/instances/default"
touch "$BIONIC_HOME/instances/default/user-data-marker"
(cd "$REPO_ROOT" && pnpm bionicai uninstall)

test ! -e "$BIONIC_HOME/cli"
test ! -e "$PC_HOME/.local/bin/bionicai"
test -f "$BIONIC_HOME/instances/default/user-data-marker"
