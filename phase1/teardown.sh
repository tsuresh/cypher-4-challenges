#!/usr/bin/env bash
# phase1/teardown.sh — remove Phase 1 challenge resources & containers.
# Leaves the VM/network (gcp/teardown.sh handles those). Idempotent.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
require docker
CH="$REPO_ROOT/phase1/challenges"
export PHASE1_VM="${PHASE1_VM:-cypher-phase1}"

step "Tearing down GCP/kind/dind challenge resources"
for c in 01-open-warehouse 04-metadata-mischief 06-signed-and-sealed \
         07-too-many-permissions 08-careless-container \
         09-peering-into-the-cluster 10-function-leak 11-the-escalation; do
  [[ -x "$CH/$c/teardown.sh" || -f "$CH/$c/teardown.sh" ]] && bash "$CH/$c/teardown.sh" || true
done

step "Stopping CTFd + container challenges"
( cd "$REPO_ROOT/phase1"
  docker compose --env-file "$REPO_ROOT/.env" down -v )

ok "Phase 1 torn down. Run gcp/teardown.sh to remove the VM/network."
