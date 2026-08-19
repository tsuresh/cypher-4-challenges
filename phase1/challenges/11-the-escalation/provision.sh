#!/usr/bin/env bash
# 11 The Escalation — two-step IAM chain:
#   leaked low-priv key  ->  impersonate one higher SA  ->  read the flag secret.
# The low-priv SA can VIEW service accounts and has tokenCreator on exactly ONE
# higher SA (aperide-admin), which alone can read the secret. Nothing broader.
# Expects CHAL_FLAG. Writes the low-priv key here. Prints "CONNECT=...".
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SECRET="aperide-crown-jewels"
ADMIN_ID="aperide-admin"
LOW_ID="aperide-lowpriv"
KEY_OUT="$HERE/aperide-lowpriv-sa-key.json"

step "11: secret + higher SA"
ensure_secret "$SECRET" "$CHAL_FLAG"
ADMIN_EMAIL="$(ensure_sa "$ADMIN_ID" "Ape Ride Admin (elevated)")"
grant_secret_role "$SECRET" "$ADMIN_EMAIL" roles/secretmanager.secretAccessor

step "11: low-privilege SA (the leaked one)"
LOW_EMAIL="$(ensure_sa "$LOW_ID" "Ape Ride Batch (low priv)")"
# Enough to ENUMERATE service accounts & read their IAM policy (discover the path).
grant_project_role "$LOW_EMAIL" roles/iam.serviceAccountViewer
# The one escalation edge: low-priv may mint tokens for the admin SA.
grant_sa_impersonation "$ADMIN_EMAIL" "$LOW_EMAIL" roles/iam.serviceAccountTokenCreator

step "11: exporting the low-priv key (challenge attachment)"
[[ -f "$KEY_OUT" ]] && rm -f "$KEY_OUT"
make_sa_key "$LOW_EMAIL" "$KEY_OUT"

ok "11: provisioned. low=$LOW_EMAIL -> admin=$ADMIN_EMAIL -> secret=$SECRET"
echo "CONNECT=Start from the attached low-priv key; find which SA you can impersonate; read secret '${SECRET}' as it."
