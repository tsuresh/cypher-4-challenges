#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
GC functions delete pwn --region "$GCP_REGION" --quiet >/dev/null 2>&1 || true
delete_sa "ruhunu-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
delete_sa "ruhunu-core@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
GC iam roles delete ruhunuDeployer --quiet >/dev/null 2>&1 || true
delete_secret "ruhunu-crownjewels"
rm -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deployer-sa-key.json"
ok "h02: torn down"
