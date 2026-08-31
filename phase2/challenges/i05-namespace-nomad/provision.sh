#!/usr/bin/env bash
# i05 Namespace Nomad — apply the RBAC-misconfigured manifests to the finals
# cluster. Expects CHAL_FLAG + a kubeconfig context pointing at the cluster.
# Prints CONNECT=.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEAM="${TEAM:-team01}"
FLAG_B64="$(printf '%s' "$CHAL_FLAG" | base64 -w0)"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
sed -e "s|__FLAG_B64__|${FLAG_B64}|" -e "s|__TEAM__|${TEAM}|g" "$HERE/k8s/challenge.yaml" > "$TMP"

step "i05: applying RBAC challenge manifests for team ${TEAM}"
kubectl apply -f "$TMP" >/dev/null
kubectl -n "apps-${TEAM}" wait --for=condition=Ready pod/patient-worker --timeout=120s >/dev/null || true

ok "i05: provisioned. Foothold: kubectl -n apps-${TEAM} exec patient-worker"
echo "CONNECT=Shell into the apps-${TEAM}/patient-worker pod; its token can read the secret in records-${TEAM}."
