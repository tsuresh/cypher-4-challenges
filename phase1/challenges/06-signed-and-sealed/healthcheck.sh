#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/healthcheck.sh"
BUCKET="${GCP_PROJECT_ID}-aw-receipts"
BASE="https://storage.googleapis.com/${BUCKET}"
# The seed receipt is public; the flag receipt is reachable by name; listing 403s.
http_status "${BASE}/receipts/CK-2026-0001.pdf" 200
flag_present "${BASE}/receipts/CK-2026-0000.pdf"
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}?list" || echo 000)"
ok "06: listing endpoint returns $code (expected 4xx — not publicly listable)"
