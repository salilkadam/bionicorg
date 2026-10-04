# Deployment Checklist: Bionic (Paperclip) to org.baisoln.com

## Prerequisites (Infrastructure)
- [x] Namespace `bionicorg` exists
- [x] CNPG cluster `pg-ceph` running (2/2 instances)
- [x] ClusterIssuer `letsencrypt-prod` ready
- [x] ClusterSecretStore `vault-backend` valid
- [x] Kong ingress controller running
- [x] cert-manager running
- [x] external-secrets-operator running
- [x] Keycloak running (keycloak ns, keycloak-0 pod)
- [x] MinIO running (minio ns, 3 replicas)
- [x] dockerhub-pull-secret exists in bionicorg ns

## Step 1: Image Push
- [ ] Push `docker4zerocool/bionic:71d7f47fe` to Docker Hub
- [ ] Verify image is pullable from Docker Hub

## Step 2: PostgreSQL Setup
- [ ] Create `bionicorg` user in pg-ceph cluster
- [ ] Create `bionicorg` database in pg-ceph cluster
- [ ] Save generated password for Vault

## Step 3: Keycloak Setup
- [ ] Create Keycloak client `bionic-org` in realm `Bionic`
- [ ] Record client_id and client_secret

## Step 4: Vault Secrets
- [ ] Populate Vault path `t6-apps/bionic-org/config` with:
  - [ ] `database_url`
  - [ ] `better_auth_secret`
  - [ ] `session_secret`
  - [ ] `keycloak_client_id`
  - [ ] `keycloak_client_secret`
  - [ ] `vault_token`
  - [ ] `minio_root_user`
  - [ ] `minio_root_password`

## Step 5: Helm Deploy
- [ ] Run `helm upgrade --install bionic-org deploy/helm/bionic-org --namespace bionicorg --set "image.tag=71d7f47fe" --set "domain=org.baisoln.com" --create-namespace --wait --timeout 5m --atomic`
- [ ] Verify pods are Running
- [ ] Verify rollout status

## Step 6: Post-Deploy Verification
- [ ] Check ExternalSecret synced
- [ ] Check TLS certificate provisioned
- [ ] Check pod health (no restarts, no crash loops)
- [ ] Verify DNS resolves org.baisoln.com
- [ ] Verify HTTP health endpoint responds
- [ ] Check Keycloak login flow works
