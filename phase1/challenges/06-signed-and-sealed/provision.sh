#!/usr/bin/env bash
# 06 Signed and Sealed — a bucket whose objects are individually public with
# guessable, sequential names, but listing is DISabled. Teams get one receipt
# URL and must enumerate the object name to reach the flag receipt.
# Expects CHAL_FLAG. Prints "CONNECT=<https url to the seed receipt>".
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

BUCKET="${GCP_PROJECT_ID}-aw-receipts"
BASE="https://storage.googleapis.com/${BUCKET}"

step "06: creating fine-grained bucket gs://${BUCKET} (listing stays private)"
if ! GS ls -b "gs://${BUCKET}" >/dev/null 2>&1; then
  # -b off => fine-grained ACLs so we can make individual objects public
  # WITHOUT granting bucket-level list. That's the enumeration gap.
  GS mb -p "$GCP_PROJECT_ID" -l "$GCP_REGION" -b off "gs://${BUCKET}" >/dev/null
fi

tmp="$(mktemp -d)"
# Public, linked receipts (decoys).
for n in 0001 0002 0003; do
  printf 'Arugam Waves — booking receipt %s\nsurf camp, 3 nights, paid.\n' "$n" > "$tmp/CK-2026-${n}.pdf"
done
# The flag receipt: the "template" object 0000, not linked anywhere.
printf 'Arugam Waves — receipt template (INTERNAL)\nvoucher code: %s\n' "$CHAL_FLAG" \
  > "$tmp/CK-2026-0000.pdf"

for n in 0000 0001 0002 0003; do
  GS cp "$tmp/CK-2026-${n}.pdf" "gs://${BUCKET}/receipts/CK-2026-${n}.pdf" >/dev/null
  GS acl ch -u AllUsers:R "gs://${BUCKET}/receipts/CK-2026-${n}.pdf" >/dev/null
done
rm -rf "$tmp"

ok "06: receipts uploaded, objects public, listing disabled"
echo "CONNECT=${BASE}/receipts/CK-2026-0001.pdf"
