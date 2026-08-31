#!/usr/bin/env bash
# i04 — build the return-to-sender binary attachment (No-PIE / no-canary). The
# per-team exploitable service runs from the same binary via the whale container.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gcc -O0 -fno-stack-protector -no-pie -w -o "$HERE/return-to-sender" "$HERE/src/gateway.c"
ok "i04: built return-to-sender"
echo "CONNECT=nc <vm-ip> <port>   (binary attached for offline analysis)"
