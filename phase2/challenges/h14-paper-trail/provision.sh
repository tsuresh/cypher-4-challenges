#!/usr/bin/env bash
# h14 — generate the per-team audit-logs.tar.gz attachment from CHAL_FLAG.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$REPO_ROOT/.venv/bin/python"; [ -x "$PY" ] || PY=python3
"$PY" "$HERE/gen.py" "$CHAL_FLAG" "$HERE/audit-logs.tar.gz" >/dev/null
ok "h14: wrote audit-logs.tar.gz"
echo "CONNECT=Download audit-logs.tar.gz (GCP Cloud Audit Log export)"
