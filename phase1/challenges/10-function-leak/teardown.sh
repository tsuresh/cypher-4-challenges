#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
GC functions delete ruhunu-greeting --gen2 --region "$GCP_REGION" --quiet 2>/dev/null || true
echo "10 function removed"
