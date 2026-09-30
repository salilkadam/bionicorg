# Hermes Gateway Adapter Compatibility Shim

`@bionicai/adapter-hermes-gateway` is a deprecated compatibility shim.

Use `@bionicai/hermes-bionic-adapter` for new installs and import gateway
entrypoints from `@bionicai/hermes-bionic-adapter/gateway`. The adapter
type remains `hermes_gateway`; only package ownership changed.

`hermes_gateway` is for an already-running Hermes API server. It does not start
the local Hermes CLI. If Bionic should launch local `hermes chat` as a child
process, use `hermes_local` from `@bionicai/hermes-bionic-adapter`
instead.

The shim preserves the legacy exports for one release:

- `.`
- `./server`
- `./ui`
- `./cli`
- `./ui-parser`

These exports forward to the unified Hermes package. Existing
`@bionicai/adapter-hermes-gateway` plugin installs should continue to load
during the compatibility window, but should migrate to
`@bionicai/hermes-bionic-adapter` before the shim is removed.
