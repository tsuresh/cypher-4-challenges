#!/usr/bin/env bash
# h03 Off the Node — GKE Workload Identity misconfig. The pod's GSA is powerless,
# but the node pool exposes GCE metadata (concealment OFF), so a pod can steal the
# NODE SA token, which can read the flag secret. De-risked: ONE small cluster, a
# per-team NAMESPACE (not per-team clusters). Expects CHAL_FLAG. Prints CONNECT=.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER="${PHASE2_GKE:-cypher-finals}"; NS="${TEAM_NS:-team01}"

step "h03: enabling APIs + secret + identities"
ensure_apis container.googleapis.com secretmanager.googleapis.com
ensure_secret "pearl-core-flag" "$CHAL_FLAG"
POD_SA="$(ensure_sa pearl-pod  "Pearl pod (powerless)")"
NODE_SA="$(ensure_sa pearl-node "Pearl node runtime")"
# node SA can read the flag secret (broader than the pod); pod SA gets nothing
grant_secret_role "pearl-core-flag" "$NODE_SA" roles/secretmanager.secretAccessor

if ! GC container clusters describe "$CLUSTER" --region "$GCP_REGION" >/dev/null 2>&1; then
  step "h03: creating small GKE cluster with Workload Identity"
  GC container clusters create "$CLUSTER" --region "$GCP_REGION" \
    --workload-pool="${GCP_PROJECT_ID}.svc.id.goog" \
    --num-nodes=1 --machine-type=e2-standard-2 \
    --service-account="$NODE_SA" \
    --workload-metadata=GCE_METADATA \
    --quiet >/dev/null
  ok "Created cluster $CLUSTER (node pool exposes GCE_METADATA — the intended flaw)"
fi
GC container clusters get-credentials "$CLUSTER" --region "$GCP_REGION" >/dev/null 2>&1

# WI binding: KSA <ns>/app -> pearl-pod GSA
GC iam service-accounts add-iam-policy-binding "$POD_SA" \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[${NS}/app]" --quiet >/dev/null 2>&1 || true

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
sed -e "s|__NS__|${NS}|g" -e "s|__PROJECT__|${GCP_PROJECT_ID}|g" "$HERE/k8s/workload.yaml" > "$TMP"
kubectl apply -f "$TMP" >/dev/null

ok "h03: provisioned namespace $NS on cluster $CLUSTER"
echo "CONNECT=kubectl -n ${NS} exec frontend — steal the node SA token via metadata, read secret 'pearl-core-flag'"
