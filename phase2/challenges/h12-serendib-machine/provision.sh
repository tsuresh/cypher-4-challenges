#!/usr/bin/env bash
# h12 — build the static serendib-machine attachment from CHAL_FLAG (bytecode
# generated per flag; the flag is never a literal in the binary).
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$REPO_ROOT/.venv/bin/python"; [ -x "$PY" ] || PY=python3
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
"$PY" "$HERE/src/gen.py" "$CHAL_FLAG" > "$TMP/program.h"
gcc -O2 -no-pie -w -I"$TMP" -o "$HERE/serendib-machine" "$HERE/src/vm.c"
ok "h12: built serendib-machine"
echo "CONNECT=Download serendib-machine (static x86-64 ELF)"
