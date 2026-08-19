#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
delete_bucket "${GCP_PROJECT_ID}-aw-receipts"
echo "06 bucket removed"
