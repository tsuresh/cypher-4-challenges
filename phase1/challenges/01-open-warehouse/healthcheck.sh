#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
require gsutil
BUCKET="${GCP_PROJECT_ID}-ck-warehouse"
if gsutil cat "gs://${BUCKET}/inventory/internal-notes.txt" 2>/dev/null | grep -qE "${FLAG_PREFIX}\{[^}]+\}"; then
  ok "01: public bucket serves the flag"
else
  err "01 FAIL: flag not readable from gs://${BUCKET}"; exit 1
fi
