#!/usr/bin/env bash
# m03 healthcheck / scripted solve: run the oracle, recover SECRET by byte-at-a-time
# ECB decryption, confirm it equals the flag. Uses the project venv (single process
# => stable key), mirroring the single-worker prod container.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{ecb_byte_at_a_time_echo}'
PORT="${PORT:-8903}"
PY=""; [ -x "$HERE/../../../.venv/bin/python" ] && PY="$HERE/../../../.venv/bin/python" || PY=python3
"$PY" -c "import flask, Crypto" 2>/dev/null || "$PY" -m pip install --quiet flask pycryptodome

FLAG="$FLAG" PORT="$PORT" "$PY" "$HERE/app/app.py" &
SVC=$!; trap 'kill "$SVC" 2>/dev/null || true' EXIT
for i in $(seq 1 30); do curl -fsS "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.5; done

REC="$("$PY" - "$PORT" <<'PY'
import sys, urllib.request
port=sys.argv[1]; BS=16
def enc(data:bytes)->bytes:
    u=f"http://127.0.0.1:{port}/encrypt?data={data.hex()}"
    import json
    return bytes.fromhex(json.load(urllib.request.urlopen(u))["ciphertext"])
known=b""
while True:
    pad=b"A"*((BS-1-(len(known)%BS)))
    blk=len(known)//BS
    target=enc(pad)[blk*BS:(blk+1)*BS]
    hit=None
    for b in range(256):
        if enc(pad+known+bytes([b]))[blk*BS:(blk+1)*BS]==target:
            hit=b; break
    if hit is None:                 # no match -> hit the PKCS7 padding boundary
        break
    known+=bytes([hit])
    if known.endswith(b"}"):        # flag terminator reached
        break
sys.stdout.write(known.decode("latin1"))
PY
)"
echo "recovered: $REC"
case "$REC" in
  *"$FLAG"*) echo "m03 healthcheck rc=0"; exit 0 ;;
  *)         echo "m03 healthcheck FAILED (got: $REC)"; exit 1 ;;
esac
