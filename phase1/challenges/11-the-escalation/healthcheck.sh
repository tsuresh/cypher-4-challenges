#!/usr/bin/env bash
# Verifies the chain works AND that the low-priv SA cannot read the secret directly.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="$HERE/aperide-lowpriv-sa-key.json"
[[ -f "$KEY" ]] || die "11: low-priv key missing — run provision.sh"
ADMIN="aperide-admin@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

CFG="$(mktemp -d)"; export CLOUDSDK_CONFIG="$CFG"
gcloud auth activate-service-account --key-file="$KEY" --quiet >/dev/null 2>&1

# Negative: direct read must FAIL for low-priv.
if gcloud --project "$GCP_PROJECT_ID" secrets versions access latest \
     --secret=aperide-crown-jewels >/dev/null 2>&1; then
  err "11 FAIL: low-priv SA read the secret directly — escalation not required!"
  rm -rf "$CFG"; exit 1
fi
# Positive: read via impersonation must SUCCEED.
val="$(gcloud --project "$GCP_PROJECT_ID" secrets versions access latest \
  --secret=aperide-crown-jewels --impersonate-service-account="$ADMIN" 2>/dev/null || true)"
rm -rf "$CFG"; unset CLOUDSDK_CONFIG

grep -qE "${FLAG_PREFIX}\{[^}]+\}" <<<"$val" \
  && ok "11: two-step escalation works and direct access is denied" \
  || { err "11 FAIL: impersonation path did not yield the flag"; exit 1; }
