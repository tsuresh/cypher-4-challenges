#!/usr/bin/env bash
# Verifies the scoped SA can read the flag secret AND nothing broader.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="$HERE/ruhunu-analyst-sa-key.json"
[[ -f "$KEY" ]] || die "07: SA key missing — run provision.sh"

# Impersonate via the key in a throwaway config.
CFG="$(mktemp -d)"; export CLOUDSDK_CONFIG="$CFG"
gcloud auth activate-service-account --key-file="$KEY" --quiet >/dev/null 2>&1
val="$(gcloud --project "$GCP_PROJECT_ID" secrets versions access latest \
  --secret=ruhunu-analytics-flag 2>/dev/null || true)"
# Negative check: the SA must NOT be able to list all secrets project-wide.
if gcloud --project "$GCP_PROJECT_ID" secrets list >/dev/null 2>&1; then
  warn "07: SA can LIST secrets project-wide — tighten scope!"
fi
rm -rf "$CFG"; unset CLOUDSDK_CONFIG

grep -qE "${FLAG_PREFIX}\{[^}]+\}" <<<"$val" \
  && ok "07: scoped SA reads the flag secret" \
  || { err "07 FAIL: SA could not read the secret"; exit 1; }
