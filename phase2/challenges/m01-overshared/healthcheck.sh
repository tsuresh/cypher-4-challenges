#!/usr/bin/env bash
# m01 healthcheck (runs in the provisioned sandbox): anonymous access must FAIL,
# authenticated access must SUCCEED, and read the flag.
set -euo pipefail
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
BUCKET="${GCP_PROJECT_ID}-ck-recon"
OBJ="finance/reconciliation.csv"

# 1) anonymous must be denied (proves it's not allUsers)
if curl -fsS "https://storage.googleapis.com/${BUCKET}/${OBJ}" >/dev/null 2>&1; then
  echo "m01 healthcheck FAILED: object is anonymously readable (should require auth)"; exit 1
fi
# 2) authenticated (any account with a token) must succeed
if gsutil cat "gs://${BUCKET}/${OBJ}" 2>/dev/null | grep -qE "${FLAG_PREFIX}\{"; then
  echo "m01 healthcheck rc=0"; exit 0
fi
echo "m01 healthcheck FAILED: authenticated read did not return the flag"; exit 1
