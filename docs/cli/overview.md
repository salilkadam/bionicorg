---
title: CLI Overview
summary: CLI installation and setup
---

The Bionic CLI handles instance setup, diagnostics, and control-plane operations.

## Usage

```sh
pnpm bionicai --help
```

## Global Options

All commands support:

| Flag | Description |
|------|-------------|
| `--data-dir <path>` | Local Bionic data root (isolates from `~/.bionic`) |
| `--api-base <url>` | API base URL |
| `--api-key <token>` | API authentication token |
| `--context <path>` | Context file path |
| `--profile <name>` | Context profile name |
| `--json` | Output as JSON |

Company-scoped commands also accept `--company-id <id>`.

For clean local instances, pass `--data-dir` on the command you run:

```sh
npx bionicai run --data-dir ./tmp/bionic-dev
```

## Context Profiles

Store defaults to avoid repeating flags:

```sh
# Set defaults
npx bionicai context set --api-base http://localhost:3100 --company-id <id>

# View current context
pnpm bionicai context show

# List profiles
pnpm bionicai context list

# Switch profile
npx bionicai context use default
```

To avoid storing secrets in context, use an env var:

```sh
npx bionicai context set --api-key-env-var-name BIONIC_API_KEY
export BIONIC_API_KEY=...
```

Secret operations are available under `bionicai secrets`:

```sh
npx bionicai secrets declarations --company-id <company-id> --kind secret
npx bionicai secrets create --company-id <company-id> --name anthropic-api-key --value-env ANTHROPIC_API_KEY
npx bionicai secrets link --company-id <company-id> --name prod-stripe-key --provider aws_secrets_manager --external-ref <provider-ref>
npx bionicai secrets doctor --company-id <company-id>
npx bionicai secrets migrate-inline-env --company-id <company-id> --apply
```

Context is stored at `~/.bionic/context.json`.

## Command Categories

The CLI has two categories:

1. **[Setup commands](/cli/setup-commands)** — instance bootstrap, diagnostics, configuration
2. **[Control-plane commands](/cli/control-plane-commands)** — issues, agents, approvals, activity
