#!/usr/bin/env bash
# m01 Overshared — bucket NOT anonymous-public, but granted to
# allAuthenticatedUsers (any Google identity). Expects CHAL_FLAG. Prints CONNECT=.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

BUCKET="${GCP_PROJECT_ID}-ck-recon"
step "m01: creating bucket gs://$BUCKET (allAuthenticatedUsers)"
URI="$(ensure_bucket "$BUCKET")"                 # private to anonymous
# The intended misconfig: readable by ANY authenticated Google account.
GS iam ch allAuthenticatedUsers:objectViewer "$URI" >/dev/null
warn "Bucket $URI grants allAuthenticatedUsers:objectViewer — challenge-intended"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/finance"
{ echo "row,amount"; echo "decoy,100"; echo "flag,${CHAL_FLAG}"; } > "$TMP/finance/reconciliation.csv"
GS cp "$TMP/finance/reconciliation.csv" "$URI/finance/reconciliation.csv" >/dev/null

ok "m01: provisioned $URI"
echo "CONNECT=${URI}  (denied anonymously; readable by any authenticated Google account)"
