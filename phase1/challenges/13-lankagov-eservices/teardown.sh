#!/usr/bin/env bash
# Remove the LankaGov container (compose service c13-lankagov).
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
( cd "$REPO_ROOT/phase1" && docker compose --env-file "$REPO_ROOT/.env" rm -sf c13-lankagov ) || true
ok "13: c13-lankagov removed"
