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

The ExternalSecret expects these keys at `t6-apps/bionic-org/config`:

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
| `storage_s3_bucket` | S3 bucket name (if using S3 storage) |
| `storage_s3_endpoint` | S3 endpoint (if using S3 storage) |

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
| ExternalSecret | `bionic-org-secrets` | Vault → K8s secret sync |
| ExternalSecret | `bionic-org-pg-superuser` | PG credentials (if separate) |

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
