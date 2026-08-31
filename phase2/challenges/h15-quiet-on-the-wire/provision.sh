#!/usr/bin/env bash
# h15 — generate the capture.pcap attachment from CHAL_FLAG.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$REPO_ROOT/.venv/bin/python"; [ -x "$PY" ] || PY=python3
"$PY" "$HERE/gen.py" "$CHAL_FLAG" "$HERE/capture.pcap" >/dev/null
ok "h15: wrote capture.pcap"
echo "CONNECT=Download capture.pcap"
