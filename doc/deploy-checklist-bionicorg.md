# Paperclip (Bionic) Deployment Checklist for org.baisoln.com

## Pre-requisites

- [ ] **1. Build Paperclip Docker image** — Build `docker4zerocool/bionic:1.0.0` from repo
- [ ] **2. Create Vault secrets** — Store app secrets in Vault at `t6-apps/bionic-org/config`:
  - `database_url`, `better_auth_secret`, `session_secret`
  - `keycloak_client_id`, `keycloak_client_secret`
  - `vault_token`, `minio_root_user`, `minio_root_password`
- [ ] **3. Create PostgreSQL database & user** — In existing `pg-ceph` cluster (`pg` namespace):
  - Database: `bionicorg`
  - User: `bionicorg`
  - Update CNPG ClusterRole permissions if needed
- [ ] **4. Create Keycloak client** — In `Bionic` realm on `auth.bionicaisolutions.com`:
  - Client for `org.baisoln.com`
  - Redirect URI: `https://org.baisoln.com/api/auth/callback`
  - Capture client_id and client_secret for Vault
- [ ] **5. Create MinIO bucket** — Bucket: `bionicorg`
- [ ] **6. Verify image pull secret** — `dockerhub-pull-secret` in `bionicorg` namespace (already exists)
- [ ] **7. Verify external-secrets infra** — `vault-backend` ClusterSecretStore (already exists)
- [ ] **8. Verify CNPG store** — `cnpg-pg-ceph-store` (already exists)
- [ ] **9. Verify cert-manager ClusterIssuer** — `letsencrypt-prod` (already exists)
- [ ] **10. Deploy Helm chart** — `helm install bionic-org ./deploy/helm/bionic-org -n bionicorg`
- [ ] **11. Verify pods running** — Check `bionicorg` namespace pods are `1/1 Running`
- [ ] **12. Verify TLS certificate issued** — Check cert-manager created TLS cert for `org.baisoln.com`
- [ ] **13. Verify ingress routing** — Check Kong ingress routes `org.baisoln.com` → service
- [ ] **14. Verify connectivity** — `curl -sS -o /dev/null -w "%{http_code}" https://org.baisoln.com` → 200
- [ ] **15. Verify health endpoint** — `curl https://org.baisoln.com/api/health` returns JSON
- [ ] **16. Verify auth flow** — Test Keycloak login redirect works
