#!/usr/bin/env bash
# i03 — generate the per-team capture.txt attachment from CHAL_FLAG.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$REPO_ROOT/.venv/bin/python"; [ -x "$PY" ] || PY=python3
"$PY" "$HERE/gen.py" "$CHAL_FLAG" "$HERE/capture.txt" >/dev/null
ok "i03: wrote capture.txt"
echo "CONNECT=Download capture.txt (three e=3 ciphertexts of the same message)"
