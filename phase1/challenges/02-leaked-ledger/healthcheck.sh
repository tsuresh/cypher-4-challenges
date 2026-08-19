#!/usr/bin/env bash
# Verifies the leak is reachable and carries a flag.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/healthcheck.sh"
BASE="${1:-http://localhost:8002}"
http_status "$BASE/" 200
flag_present "$BASE/.env"
