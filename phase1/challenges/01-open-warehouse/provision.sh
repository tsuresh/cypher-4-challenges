#!/usr/bin/env bash
# 01 Open Warehouse — a public GCS bucket anyone can list & read.
# Expects CHAL_FLAG. Prints "CONNECT=gs://<bucket>".
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

BUCKET="${GCP_PROJECT_ID}-ck-warehouse"
step "01: creating PUBLIC bucket gs://${BUCKET}"
ensure_bucket "$BUCKET" public >/dev/null

tmp="$(mktemp -d)"
mkdir -p "$tmp/inventory" "$tmp/public"
echo "Ceylon Kade — tea warehouse stock export (public catalogue)"      > "$tmp/public/catalogue.txt"
echo "BOPF, OP, Pekoe, Dust grades. Contact sales@ceylonkade.lk"        >> "$tmp/public/catalogue.txt"
cat > "$tmp/inventory/stock-2026.csv" <<'CSV'
sku,grade,kg,warehouse
CK-001,BOPF,1200,Nuwara Eliya
CK-002,OP,860,Nuwara Eliya
CSV
# The mistake: an internal note with the flag, left in the same public bucket.
printf 'Internal note — DO NOT expose publicly.\nlaunch token: %s\n' "$CHAL_FLAG" \
  > "$tmp/inventory/internal-notes.txt"

GS -m cp -r "$tmp/inventory" "$tmp/public" "gs://${BUCKET}/" >/dev/null
rm -rf "$tmp"
ok "01: objects uploaded to gs://${BUCKET}"
echo "CONNECT=gs://${BUCKET}"
