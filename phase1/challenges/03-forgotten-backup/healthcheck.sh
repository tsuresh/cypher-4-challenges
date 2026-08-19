#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/healthcheck.sh"
BASE="${1:-http://localhost:8003}"
http_status "$BASE/" 200
flag_present "$BASE/backups/db_backup.sql"
