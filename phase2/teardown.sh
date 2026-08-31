#!/usr/bin/env bash
# phase2/teardown.sh — remove finals challenge resources and stop the platform.
# Leaves the VMs (delete those with gcp/teardown.sh or gcloud). Idempotent.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
CH="$REPO_ROOT/phase2/challenges"

step "Running per-challenge teardowns (cloud/GKE resources)"
for dir in "$CH"/*/; do
  [[ -f "$dir/teardown.sh" ]] && { warn "teardown $(basename "$dir")"; bash "$dir/teardown.sh" || true; }
done

step "Stopping the finals platform (CTFd + whale + frp)"
( cd "$REPO_ROOT/phase2/whale" && docker compose --env-file "$REPO_ROOT/.env" down -v ) || true

step "Removing per-team whale containers + images"
docker ps -aq --filter "name=cypher-p2" | xargs -r docker rm -f >/dev/null 2>&1 || true
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^cypher-p2/' | xargs -r docker rmi -f >/dev/null 2>&1 || true

ok "Phase 2 torn down. VMs remain — remove with: gcloud compute instances delete cypher-phase2 cypher-phase2-b --zone \$GCP_ZONE"
