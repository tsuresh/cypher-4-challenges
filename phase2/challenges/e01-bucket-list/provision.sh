#!/usr/bin/env bash
# e01 Bucket List — a world-readable, LISTABLE GCS bucket with the flag object
# hidden among decoy media. Mirrors phase1/01 but keeps listing enabled.
# Expects CHAL_FLAG. Prints "CONNECT=...".
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

BUCKET="${GCP_PROJECT_ID}-aw-surfcam"
step "e01: creating public, listable bucket gs://$BUCKET"
URI="$(ensure_bucket "$BUCKET" public)"          # allUsers:objectViewer (list+get)

# decoy media + the flag object in an out-of-place path
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for i in 01 02 03; do echo "surf clip $i" > "$TMP/clip_${i}.mp4"; done
printf '%s\n' "$CHAL_FLAG" > "$TMP/ops/handover.txt" 2>/dev/null || { mkdir -p "$TMP/ops"; printf '%s\n' "$CHAL_FLAG" > "$TMP/ops/handover.txt"; }
GS -m cp -r "$TMP"/* "$URI"/ >/dev/null

ok "e01: provisioned $URI (flag at ops/handover.txt)"
echo "CONNECT=${URI}  (public, listable: gsutil ls -r ${URI})"
