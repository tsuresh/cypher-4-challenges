#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
delete_secret "ruhunu-analytics-flag"
delete_sa "ruhunu-analyst@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
rm -f "$HERE/ruhunu-analyst-sa-key.json"
echo "07 secret + SA removed"
