#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
delete_secret "aperide-crown-jewels"
delete_sa "aperide-admin@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
delete_sa "aperide-lowpriv@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
# Remove the project-level viewer grant we added.
GC projects remove-iam-policy-binding "$GCP_PROJECT_ID" \
  --member "serviceAccount:aperide-lowpriv@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/iam.serviceAccountViewer --condition=None --quiet 2>/dev/null || true
rm -f "$HERE/aperide-lowpriv-sa-key.json"
echo "11 secrets + SAs removed"
