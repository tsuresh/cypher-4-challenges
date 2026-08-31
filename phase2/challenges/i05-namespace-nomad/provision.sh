#!/usr/bin/env bash
# i05 Namespace Nomad — apply the RBAC-misconfigured manifests to the finals
# cluster. Expects CHAL_FLAG + a kubeconfig context pointing at the cluster.
# Prints CONNECT=.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FLAG_B64="$(printf '%s' "$CHAL_FLAG" | base64 -w0)"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
sed "s|__FLAG_B64__|${FLAG_B64}|" "$HERE/k8s/challenge.yaml" > "$TMP"

step "i05: applying RBAC challenge manifests"
kubectl apply -f "$TMP" >/dev/null
kubectl -n apps wait --for=condition=Ready pod/patient-worker --timeout=120s >/dev/null || true

ok "i05: provisioned. Foothold: kubectl -n apps exec patient-worker"
echo "CONNECT=Shell into the apps/patient-worker pod; its token can read secrets in the records namespace."
