#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
delete_bucket "${GCP_PROJECT_ID}-lankagov-ci-state"
delete_secret "lankagov-registry-flag"
delete_sa "lankagov-ci@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
ok "h05: torn down"
