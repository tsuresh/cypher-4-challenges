#!/usr/bin/env bash
# 10 Function Leak — deploy an HTTP Cloud Function (gen2) with the flag in its
# environment. Unsanitised template input leaks env vars. Expects CHAL_FLAG.
# Prints "CONNECT=<function url>".
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FN="ruhunu-greeting"
step "10: deploying Cloud Function (gen2) '$FN' in $GCP_REGION"
GC functions deploy "$FN" \
  --gen2 --runtime python312 --region "$GCP_REGION" \
  --source "$HERE/src" --entry-point handler \
  --trigger-http --allow-unauthenticated \
  --memory 256Mi --max-instances 3 \
  --set-env-vars "FLAG=${CHAL_FLAG}" \
  --quiet

URL="$(GC functions describe "$FN" --gen2 --region "$GCP_REGION" \
  --format='value(serviceConfig.uri)')"
ok "10: function live at $URL"
echo "CONNECT=${URL}"
