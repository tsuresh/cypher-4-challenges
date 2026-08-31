#!/usr/bin/env bash
# e01 healthcheck (runs in the provisioned sandbox): anonymous listing must work
# and the flag object must be readable without credentials.
set -euo pipefail
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
BUCKET="${GCP_PROJECT_ID}-aw-surfcam"
# unauthenticated read via the public JSON/XML endpoint
if curl -fsS "https://storage.googleapis.com/${BUCKET}/ops/handover.txt" | grep -qE "${FLAG_PREFIX}\{"; then
  echo "e01 healthcheck rc=0"; exit 0
fi
echo "e01 healthcheck FAILED"; exit 1
