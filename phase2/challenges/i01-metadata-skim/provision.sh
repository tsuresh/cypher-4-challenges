#!/usr/bin/env bash
# i01 Metadata Skim — create the scoped backend (one bucket object the VM's SA can
# read) and the flag. The SSRF app runs on the finals VM (see whale/compose) under a
# service account scoped to ONLY this object, so a stolen token reaches nothing else.
# Expects CHAL_FLAG. Prints CONNECT= (set to the VM:port at compose time).
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

SA_ID="aperide-preview"
BUCKET="${GCP_PROJECT_ID}-aperide-preview"
step "i01: scoped SA + private bucket holding the flag"
SA_EMAIL="$(ensure_sa "$SA_ID" "Ape Ride Previewer (scoped)")"
URI="$(ensure_bucket "$BUCKET")"                 # private
printf '%s\n' "$CHAL_FLAG" | GS cp - "$URI/flag.txt" >/dev/null
# grant the SA read on ONLY this object's bucket (objectViewer on this bucket only)
GS iam ch "serviceAccount:${SA_EMAIL}:objectViewer" "$URI" >/dev/null

ok "i01: provisioned. SA=$SA_EMAIL bucket=$URI (attach this SA to the SSRF VM/instance)"
echo "CONNECT=http://<vm-ip>:8101/   (SSRF previewer; SA can read gs://${BUCKET}/flag.txt)"
