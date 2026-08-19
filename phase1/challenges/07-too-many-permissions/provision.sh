#!/usr/bin/env bash
# 07 Too Many Permissions — a low-privilege SA whose ONE role happens to be
# secretAccessor on the flag secret. Teams get its key, enumerate what they can
# do, and read the secret. Scoped so leaking it reaches ONLY this secret.
# Expects CHAL_FLAG. Writes the SA key into this dir. Prints "CONNECT=...".
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SECRET="ruhunu-analytics-flag"
SA_ID="ruhunu-analyst"
KEY_OUT="$HERE/ruhunu-analyst-sa-key.json"

step "07: creating secret '$SECRET' with the flag"
ensure_secret "$SECRET" "$CHAL_FLAG"

step "07: creating least-privilege SA '$SA_ID'"
SA_EMAIL="$(ensure_sa "$SA_ID" "Ruhunu Bank Analyst (scoped)")"

# Resource-scoped grant ONLY: accessor on this one secret. No project roles.
grant_secret_role "$SECRET" "$SA_EMAIL" roles/secretmanager.secretAccessor

step "07: exporting SA key for the team (challenge attachment)"
[[ -f "$KEY_OUT" ]] && rm -f "$KEY_OUT"
make_sa_key "$SA_EMAIL" "$KEY_OUT"

ok "07: provisioned. Secret=$SECRET SA=$SA_EMAIL"
echo "CONNECT=Activate the attached key: gcloud auth activate-service-account --key-file=ruhunu-analyst-sa-key.json ; then read secret '${SECRET}'"
