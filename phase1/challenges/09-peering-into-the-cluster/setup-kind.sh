#!/usr/bin/env bash
# 09 — build the kind cluster, deploy the Kubernetes Dashboard with skip-login,
# over-privilege its service account (rbac.yaml), and store the flag as a Secret.
# Runs ON the VM. Expects CHAL_FLAG.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
require kind kubectl
: "${CHAL_FLAG:?CHAL_FLAG required}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER=cypher09
DASH_VERSION="v2.7.0"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  step "09: creating kind cluster $CLUSTER"
  kind create cluster --config "$HERE/kind-config.yaml" --wait 120s
else
  ok "09: kind cluster already exists"
fi

KCTX="kind-${CLUSTER}"
kubectl config use-context "$KCTX" >/dev/null

step "09: deploying Kubernetes Dashboard $DASH_VERSION"
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/${DASH_VERSION}/aio/deploy/recommended.yaml"

# Enable skip-login + expose via NodePort 30009 -> host 8009.
kubectl -n kubernetes-dashboard patch deployment kubernetes-dashboard --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enable-skip-login"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--disable-settings-authorizer"}
]' || warn "dashboard args patch may already be applied"

kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard --type=json -p='[
  {"op":"replace","path":"/spec/type","value":"NodePort"},
  {"op":"add","path":"/spec/ports/0/nodePort","value":30009}
]' || warn "dashboard svc patch may already be applied"

step "09: applying over-privileged RBAC (the vulnerability)"
kubectl apply -f "$HERE/rbac.yaml"

step "09: storing the flag as a Secret (aperide/driver-config)"
kubectl create namespace aperide --dry-run=client -o yaml | kubectl apply -f -
kubectl -n aperide create secret generic driver-config \
  --from-literal=note="dispatch API credentials" \
  --from-literal=flag="${CHAL_FLAG}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n kubernetes-dashboard rollout status deployment/kubernetes-dashboard --timeout=120s || true
ok "09: dashboard reachable on host port 8009 (https). Click Skip -> Secrets -> aperide/driver-config"
