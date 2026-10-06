# Bionic Kubernetes Deployment

Helm charts and deployment scripts for deploying Bionic to a Kubernetes cluster.

## Quick Start

### Prerequisites

1. **Cluster access** — `kubectl` configured with admin access
2. **Helm** — v3.x installed
3. **Docker** — for building the image
4. **Git** — for version tag

### Pre-deployment Checklist

Before running `deploy.sh`, ensure these are set up:

| Step | Command | Status |
|------|---------|--------|
| 1. Create namespace | `kubectl create ns bionicorg` | ⬜ |
| 2. Create PG user/db | `./deploy/scripts/setup-postgres.sh` | ⬜ |
| 3. Create Keycloak client | `./deploy/scripts/setup-keycloak.sh` | ⬜ |
| 4. Populate Vault secrets | `./deploy/scripts/setup-vault-secrets.sh` | ⬜ |
| 5. Build & push image | `./deploy/scripts/build-and-push.sh` | ⬜ |
| 6. Create DNS record | `org.baisoln.com` → `192.168.0.210` | ⬜ |

> Step 4 generates `paperclip_secrets_master_key` **exactly once** and then
> preserves it forever. On a rebuild of an *existing* Org (DB survives), the
> Vault secret must already contain the original master key — a new key makes
> every previously encrypted managed secret unreadable.

### Deploy

```bash
# 1. Build and push the image
./deploy/scripts/build-and-push.sh

# 2. Run the full deployment (creates namespace, applies Helm, waits for rollout)
./deploy/scripts/deploy.sh

# That's it. The script handles:
# - Creating the bionicOrg namespace
# - Docker pull secret (if credentials provided via DOCKER_USERNAME/DOCKER_PASSWORD)
# - Helm install/upgrade with the correct image tag
# - Waiting for deployment readiness
```

## Helm Values Reference

See `helm/bionic-org/values.yaml` for all configurable options. Key values:

```yaml
namespace: bionicorg
domain: org.bailsoln.com

image:
  repository: docker4zerocool/bionic
  tag: ""  # defaults to chart appVersion
  pullPolicy: Always

postgresql:
  cluster: pg-ceph
  namespace: pg
  database: bionicOrg
  username: bionicOrg

vault:
  path: t6-apps/bionic-org/config
  secretStore: vault-backend
  masterKeySecretKey: paperclip_secrets_master_key

persistence:            # /paperclip instance state — DO NOT disable
  enabled: true
  size: 20Gi
  storageClassName: nfs-client   # RWX: rolling updates never deadlock
  mountPath: /paperclip
  fsGroup: 1000

keycloak:
  url: https://auth.bailsoln.com
  realm: Bionic

ingress:
  className: kong
  tls:
    enabled: true
    secretName: bionic-org-tls
```

## Vault Secrets

Two Vault paths feed this deployment via ESO (both synced every 5 min — never edit the K8s Secrets directly):

1. **`t6-apps/bionic-org/config`** → K8s Secret `bionic-org-secrets` (app config):

| Key | Description |
|-----|-------------|
| `database_url` | PostgreSQL connection string |
| `better_auth_secret` | Better Auth session secret (random) |
| `session_secret` | Session encryption secret (random) |
| `keycloak_client_id` | Keycloak client ID |
| `keycloak_client_secret` | Keycloak client secret |
| `vault_token` | Vault API token |
| `minio_root_user` | MinIO access key |
| `minio_root_password` | MinIO secret key |
| `paperclip_secrets_master_key` | **AES-256-GCM master key** (`local_encrypted` provider). base64 of a 32-byte key. Generated once by `setup-vault-secrets.sh`; NEVER regenerate while encrypted secret versions exist in the DB — all managed secrets (agent API keys, OAuth tokens, provider keys) become permanently undecryptable. Backed up off-cluster. |
| `storage_s3_bucket` | S3 bucket name (if using S3 storage) |
| `storage_s3_endpoint` | S3 endpoint (if using S3 storage) |

2. **`shared/api-keys`** (org-wide shared provider keys) → K8s Secret `bionic-org-api-keys`, mounted via `envFrom` so adapter child processes inherit provider credentials. Contains `anthropic_api_key`, `claude_subscription_token`, `github_token`, `openai_api_key`, `gemini_api_key`, `openrouter_api_key`, and more. The deployment also exposes uppercase aliases (`ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `GITHUB_TOKEN`, `OPENAI_API_KEY`).

> **Re-seeding Board managed secrets:** after a Case-C rebuild, read the needed values from `bionic-org-api-keys` (`kubectl -n bionicorg get secret bionic-org-api-keys -o go-template=...`) and enter them once in the Board UI — the UI encrypts them into the DB under the master key; the env wiring covers CLI-level fallback.

## Kubernetes Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| Namespace | `bionicorg` | Isolation namespace |
| ServiceAccount | `bionic-org-sa` | Service account for the pod |
| ConfigMap | `bionic-org-config` | Non-secret environment variables |
| Service | `bionic-org` | ClusterIP service on port 80→3100 |
| Deployment | `bionic-org` | Main application deployment |
| Ingress | `bionic-org` | Kong ingress with TLS |
| Certificate | `bionic-org-tls` | cert-manager TLS certificate |
| PVC | `bionic-org-data` | NFS RWX 20Gi at `/paperclip`: instance state (signing keys, local_disk storage, agent workspaces) |
| ExternalSecret | `bionic-org-secrets` | Vault → K8s secret sync (5m), app config |
| ExternalSecret | `bionic-org-api-keys` | Vault `shared/api-keys` → K8s secret sync (5m), provider keys |
| ExternalSecret | `bionic-org-pg-superuser` | PG credentials (if separate) |

## Disaster Recovery — rebuilding the Org from scratch

Source of truth for re-creation is **this chart + Vault + the CNPG database**.
The K8s Secret `bionic-org-secrets` is only a 5-minute cache of Vault —
never edit it directly (`kubectl patch` edits get reverted by ESO).

### Case A — app/pods deleted, database and Vault intact (common case)

```bash
helm upgrade --install bionic-org ./deploy/helm/bionic-org --namespace bionicorg
# ESO re-syncs the K8s secret; the master key comes from Vault via
# PAPERCLIP_SECRETS_MASTER_KEY; /paperclip re-attaches from the NFS PVC.
```

### Case B — namespace wiped, DB + Vault + NFS share intact

Run the Pre-deployment Checklist steps 1, 4 (skip 2–3, 6), then `deploy.sh`.
Do **not** let `setup-vault-secrets.sh` regenerate the master key (it won't —
it preserves; only `--rotate-master-key` changes it).

### Case C — everything lost (fresh cluster, fresh DB)

1. Full checklist (steps 1–6). `setup-vault-secrets.sh` generates a brand-new
   master key — fine for a fresh DB; back it up off-cluster immediately.
2. After rollout, sign in via Keycloak and re-enter all managed secrets in the
   Board UI (Anthropic/API-provider keys, Claude OAuth, GitHub token,
   GPU-cluster key). These live encrypted **in the DB** under the master key —
   they are not in Vault or the PVC and cannot be restored from this repo.
3. Recreate the watchdog agent: copy `deploy/` into the app pod and run
   `deploy/scripts/create-sr-engineer-agent.sh`, then follow its NEXT output
   (Claude token → bind → enable heartbeat). Also re-run
   `register-cluster-mcp-servers.sh` and `apply-agent-opencode-data-isolation.sh`.

### Verify any restore

```bash
kubectl -n bionicorg get pods,externalsecret,pvc
# Externalsecret READY=True, PVC Bound, pod env resolves master key:
kubectl -n bionicorg exec deploy/bionic-org -- node -e \
  'console.log("master key set:", !!process.env.PAPERCLIP_SECRETS_MASTER_KEY)'
curl -sk https://org.baisoln.com/api/health
# Then check a heartbeat run reaches a real model call (no
# "Secret decryption failed" in pod logs).
```

## Troubleshooting

### Pod stuck in ContainerCreating

```bash
kubectl -n bionicorg describe pod -l app=bionic-org
# Check for image pull issues (need dockerhub-pull-secret)
```

### ExternalSecret not syncing

```bash
kubectl -n bionicorg describe externalsecret bionic-org-secrets
# Check Vault path exists: vault kv get t6-apps/bionic-org/config
```

### TLS not provisioning

```bash
kubectl -n bionicorg describe certificate bionic-org-tls
# Verify letsencrypt-prod ClusterIssuer is ready
kubectl get clusterissuer letsencrypt-prod
```

### Ingress not routing

```bash
kubectl -n bionicorg describe ingress bionic-org
# Check Kong pods are running
kubectl get pods -n kong
```

### Database connection failure

```bash
# Test connectivity from the pod
kubectl -n bionicorg exec -it deployment/bionic-org -- bash
psql "postgresql://bionicOrg:<password>@pg-ceph-rw.pg.svc.cluster.local:5432/bionicOrg"
```

## Customization

### Override values from CLI

```bash
helm upgrade --install bionic-org ./deploy/helm/bionic-org \
  --namespace bionicorg \
  --set image.tag=abc1234 \
  --set domain=custom.bailsoln.com \
  --set "env.PAPERCLIP_STORAGE_PROVIDER=s3"
```

### Using MinIO/S3 instead of local disk

Set in Helm values or via env override:

```yaml
env:
  PAPERCLIP_STORAGE_PROVIDER: s3
```

Then ensure Vault has:
- `storage_s3_bucket`
- `storage_s3_endpoint`
- `storage_s3_region` (optional)

## Architecture

```
                    ┌─────────────┐
                    │   DNS       │
                    │ org.bailsoln│
                    │    .com     │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │     Kong    │
                    │  Ingress    │
                    │  (K3s LB)   │
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │     bionicOrg Namespace  │
              │                         │
              │  ┌─────────────────┐    │
              │  │  Deployment     │    │
              │  │  (Port 3100)    │    │
              │  └────────┬────────┘    │
              │           │              │
              │  ┌────────▼────────┐    │
              │  │   Service       │    │
              │  │   (Port 80)     │    │
              │  └─────────────────┘    │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │    CNPG (pg-ceph)       │
              │    PostgreSQL 5432       │
              └─────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │    Vault (ESO)          │
              │    t6-apps/bionic-org/  │
              └─────────────────────────┘
```

## Cluster MCP servers (Loc-*)

`deploy/mcp/bionic-org-mcp-servers.json` is the discovered catalog of every
MCP-shaped workload in the cluster (internal DNS, Streamable HTTP where
supported). `deploy/scripts/register-cluster-mcp-servers.sh` registers the
`status: ready` entries into a Paperclip company as `Loc-*` tool connections
(auth kind `none` — internal cluster traffic bypasses the mcp-ingress API-key
wall; `PAPERCLIP_DEPLOYMENT_EXPOSURE=private` lets the endpoint guard accept
private URLs) and runs health-check + catalog refresh for each. Re-run it
any time after recreating the org from scratch.

Cluster prerequisites applied for these connections (see
`cluster_prerequisites` in the catalog JSON): the comfy host allowlist, the
mail-bridge service client-IP session affinity, and the private exposure flag.

Entries that are `oauth_gated` (Letta, Google Workspace: Keycloak realm
`mcp` bearer required), `sse_only` (search MCP: Paperclip speaks Streamable
HTTP), `unavailable` (qdrant, scaled to zero), `not_mcp` (docs swagger-ui),
or `unreachable` (archon) are documented but intentionally not registered.

## Per-agent OpenCode data isolation

All agents execute `opencode run` as the same OS user in the app pod, so they
would otherwise share one SQLite database
(`/paperclip/.local/share/opencode/opencode.db`). opencode 1.18.x kills the
whole run on `SQLITE_BUSY` (upstream anomalyco/opencode#33320, #47566, #48416),
which surfaced as `Error: Unexpected error / database is locked` and
`Failed to execute statement` whenever two agents started together.

`scripts/apply-agent-opencode-data-isolation.sh` gives every agent its own
`XDG_DATA_HOME`/`XDG_STATE_HOME` under the `/paperclip` PVC
(`/paperclip/agents/<agentId>/opencode/…`), seeded with a copy of the shared DB
so session resume keeps working. The bindings live in
`agents.adapter_config.env` (plain values), so they survive pod restarts; run
the script again after adding agents.

## Sr. Engineer (IT department watchdog agent)

A 6th agent, **Sr. Engineer** (`6c3d9ec8-604d-4621-98b3-761931c72225`), reports
to the CIO, carries `metadata.department = "IT"`, and patrols Paperclip failures
on a 5-minute heartbeat: failed/timed-out runs, the recovery backlog, and its
own assigned issues. It retries transient failures, applies the known-failure
catalogue fixes, and goes back to sleep when there is nothing actionable. Its
brain is the Claude subscription (`claude_local` adapter).

- Runbook (instructions bundle entry file): `deploy/agents/sr-engineer-AGENTS.md`
- Idempotent creation: `deploy/scripts/create-sr-engineer-agent.sh`
  (requires `PAPERCLIP_BOARD_TOKEN`; runs inside the app pod)

Claude auth note: `claude_local` has **no device login** and the setup-token
session flow needs a managed sandbox environment. Use the owner-pasted token
path instead:

1. `claude setup-token` on any machine signed into the subscription.
2. `POST /api/companies/<cid>/claude-oauth-token {"token":"sk-ant-oat01-..."}`
3. `PATCH /api/agents/<id> {"applyStoredClaudeLogin":true}`
4. `PATCH /api/agents/<id> {"runtimeConfig":{"heartbeat":{"enabled":true,"intervalSec":300,"maxConcurrentRuns":1}}}`

The heartbeat ships **disabled** at creation so the agent never loops
`setup_failed` before its Claude login exists. Memory: with 6 agents at
`maxConcurrentRuns:1` the pod stays under the 6Gi limit; re-check
`kubectl top pod` after the first week of patrol activity.
