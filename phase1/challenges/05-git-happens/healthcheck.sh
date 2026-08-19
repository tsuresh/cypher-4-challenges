#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/healthcheck.sh"
BASE="${1:-http://localhost:8005}"
http_status "$BASE/" 200
http_status "$BASE/.git/HEAD" 200
# Working tree must NOT expose the secret directly.
if curl -fsS --max-time 5 "$BASE/config.php" 2>/dev/null | grep -q "${FLAG_PREFIX}{"; then
  err "05 FAILED: flag reachable from working tree; it must live only in .git history"
  exit 1
fi
ok "05 healthcheck: .git exposed, working tree clean"
