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

step "06: creating bucket gs://${BUCKET} (objects readable, listing stays private)"
if ! GS ls -b "gs://${BUCKET}" >/dev/null 2>&1; then
  GS mb -p "$GCP_PROJECT_ID" -l "$GCP_REGION" "gs://${BUCKET}" >/dev/null
fi
# The enumeration gap: anonymous callers may GET a KNOWN object path but may NOT
# list the bucket. roles/storage.legacyObjectReader is exactly storage.objects.get
# with no storage.objects.list. This replaces per-object ACLs (`mb -b off` plus
# `acl ch -u AllUsers:R`), which silently do nothing wherever the
# constraints/storage.uniformBucketLevelAccess org policy is enforced — leaving
# the challenge unsolvable with no error at provision time.
GS iam ch allUsers:legacyObjectReader "gs://${BUCKET}" >/dev/null

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
done
rm -rf "$tmp"

ok "06: receipts uploaded, objects public, listing disabled"
echo "CONNECT=${BASE}/receipts/CK-2026-0001.pdf"
