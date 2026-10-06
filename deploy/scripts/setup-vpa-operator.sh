#!/usr/bin/env bash
# Installs the Kubernetes Vertical Pod Autoscaler (VPA) operator so that the
# bionic-org VerticalPodAutoscaler template (deploy/helm/bionic-org/templates/
# vpa.yaml) can render and take effect.
#
# The VPA CRD is cluster-scoped infrastructure and is NOT part of the app
# release, so it is installed here (idempotently) rather than by the app chart.
# After this runs, `helm upgrade` the bionic-org chart and the VPA becomes live.
#
# Cluster is k3s v1.33 (in-place Pod resize is beta / enabled by default), which
# lets VPA updateMode=InPlaceOrRecreate resize the running pod's memory request
# without evicting it (eviction would kill in-flight agent runs).
#
# Idempotent: re-running is safe. Requires helm and kubectl on PATH.
set -euo pipefail

VPA_NAMESPACE="${VPA_NAMESPACE:-vpa}"
VPA_CHART_VERSION="${VPA_CHART_VERSION:-1.3.0}"   # FairwindsSquare VPA helm chart

echo "==> Adding FairwindsSquare VPA helm repo"
helm repo add fairwinds-stable https://charts.fairwinds.com/stable >/dev/null 2>&1 || true
helm repo update fairwinds-stable >/dev/null

echo "==> Creating ${VPA_NAMESPACE} namespace"
kubectl create namespace "${VPA_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing/upgrading VPA operator (recommender + admission-controller; updater included)"
# recommender.enabled + admissionController.enabled give recommendation + apply;
# updater.enabled drives the InPlaceOrRecreate eviction/resize decisions.
helm upgrade --install vpa fairwinds-stable/vpa \
  --namespace "${VPA_NAMESPACE}" \
  --version "${VPA_CHART_VERSION}" \
  --set recommender.enabled=true \
  --set admissionController.enabled=true \
  --set updater.enabled=true \
  --wait

echo "==> Waiting for the VerticalPodAutoscaler CRD to be established"
kubectl wait --for=condition=Established \
  crd/verticalpodautoscalers.autoscaling.k8s.io --timeout=120s

echo "==> VPA operator ready."
echo "    Next: helm upgrade --install bionic-org deploy/helm/bionic-org --namespace bionicorg"
echo "    Verify: kubectl -n bionicorg get vpa bionic-org -o wide"
