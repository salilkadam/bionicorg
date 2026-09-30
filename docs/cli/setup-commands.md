---
title: Setup Commands
summary: Onboard, run, doctor, and configure
---

Instance setup and diagnostics commands.

## `bionicai run`

One-command bootstrap and start:

```sh
pnpm bionicai run
```

Does:

1. Auto-onboards if config is missing
2. Runs `bionicai doctor` with repair enabled
3. Starts the server when checks pass

Choose a specific instance:

```sh
npx bionicai run --instance dev
```

## `bionicai onboard`

Interactive first-time setup:

```sh
pnpm bionicai onboard
```

If Bionic is already configured, rerunning `onboard` keeps the existing config in place. Use `bionicai configure` to change settings on an existing install.

First prompt:

1. `Quickstart` (recommended): local defaults (embedded database, no LLM provider, local disk storage, default secrets)
2. `Advanced setup`: full interactive configuration

Start immediately after onboarding:

```sh
pnpm bionicai onboard --run
```

Quickstart defaults + immediate start:

```sh
pnpm bionicai onboard --yes
```

When onboarding starts Bionic from an interactive terminal, it opens the
onboarding page in your browser once. Non-interactive terminals stay silent.
Suppress browser opening explicitly for headless or automated runs with either
environment variable:

```sh
BIONIC_NO_BROWSER=1 pnpm bionicai onboard --yes
BIONIC_OPEN_ON_LISTEN=false pnpm bionicai onboard --yes
```

On an existing install, `--yes` now preserves the current config and just starts Bionic with that setup.

## `bionicai doctor`

Health checks with optional auto-repair:

```sh
pnpm bionicai doctor
pnpm bionicai doctor --repair
```

Validates:

- Server configuration
- Database connectivity
- Secrets adapter configuration, including AWS Secrets Manager non-secret env
  config when selected
- Storage configuration
- Missing key files

## `bionicai configure`

Update configuration sections:

```sh
pnpm bionicai configure --section server
pnpm bionicai configure --section secrets
pnpm bionicai configure --section storage
```

`--section secrets` updates the deployment-level provider used as the fallback
for secrets that do not target a specific company vault. Per-company provider
vaults (named instances, default vault selection, multiple vaults per provider,
coming-soon GCP/Vault) live in the board UI under
`Company Settings → Secrets → Provider vaults` and the
`/api/companies/{companyId}/secret-provider-configs` API.

## `bionicai env`

Show resolved environment configuration:

```sh
pnpm bionicai env
```

This now includes bind-oriented deployment settings such as `BIONIC_BIND` and `BIONIC_BIND_HOST` when configured.

## `bionicai allowed-hostname`

Allow a private hostname for authenticated/private mode:

```sh
npx bionicai allowed-hostname my-tailscale-host
```

## Local Storage Paths

| Data | Default Path |
|------|-------------|
| Config | `~/.bionic/instances/default/config.json` |
| Database | `~/.bionic/instances/default/db` |
| Logs | `~/.bionic/instances/default/logs` |
| Storage | `~/.bionic/instances/default/data/storage` |
| Secrets key | `~/.bionic/instances/default/secrets/master.key` |

Override with:

```sh
BIONIC_HOME=/custom/home BIONIC_INSTANCE_ID=dev pnpm bionicai run
```

Or pass `--data-dir` directly on any command:

```sh
npx bionicai run --data-dir ./tmp/bionic-dev
npx bionicai doctor --data-dir ./tmp/bionic-dev
```
