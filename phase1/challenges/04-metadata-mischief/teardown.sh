#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
VM="${PHASE1_VM:-cypher-phase1}"
GC compute instances remove-metadata "$VM" --zone "$GCP_ZONE" --keys cypher-flag-04 --quiet 2>/dev/null || true
ok "04 metadata attribute removed"
