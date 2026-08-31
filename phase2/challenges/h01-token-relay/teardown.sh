#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
for sa in webhook-runner relay vault-reader; do
  delete_sa "${sa}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
done
delete_secret "ape-ride-crownjewels"
ok "h01: torn down"
