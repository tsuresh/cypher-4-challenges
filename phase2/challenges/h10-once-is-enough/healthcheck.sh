#!/usr/bin/env bash
# h10 healthcheck / scripted solve: recover the GHASH key H from two ciphertexts
# under the reused nonce (forbidden attack), forge a valid tag for a role=admin
# message, submit it, and confirm the flag comes back. Uses single-block messages
# so H has a closed form (H^2 = (T1^T2)/(C1^C2)). Runs the oracle via the venv
# (single process => stable key/nonce), matching the single-worker container.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{gcm_forbidden_attack_forge}'
PORT="${PORT:-8910}"
PY=""; [ -x "$HERE/../../../.venv/bin/python" ] && PY="$HERE/../../../.venv/bin/python" || PY=python3
"$PY" -c "import flask, Crypto" 2>/dev/null || "$PY" -m pip install --quiet flask pycryptodome

( cd "$HERE/app" && FLAG="$FLAG" PORT="$PORT" "$PY" app.py ) &
SVC=$!; trap 'kill "$SVC" 2>/dev/null || true' EXIT
for i in $(seq 1 30); do curl -fsS "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.5; done

OUT="$("$PY" - "$PORT" "$HERE/app" <<'PY'
import sys, json, urllib.request
port=sys.argv[1]; sys.path.insert(0, sys.argv[2])
import gcm
def get(u): return json.load(urllib.request.urlopen(u))
def enc(p): return get(f"http://127.0.0.1:{port}/encrypt?data={p.hex()}")
def submit(nonce,ct,tag):
    req=urllib.request.Request(f"http://127.0.0.1:{port}/submit",
        data=json.dumps({"nonce":nonce,"ct":ct.hex(),"tag":tag.hex()}).encode(),
        headers={"Content-Type":"application/json"})
    try: return json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e: return json.load(e)

b2i=lambda b:int.from_bytes(b,"big"); i2b=lambda i:i.to_bytes(16,"big")
p1=b"AAAAAAAAAAAAAAAA"; p2=b"BBBBBBBBBBBBBBBB"
r1=enc(p1); r2=enc(p2)
nonce=r1["nonce"]
C1=bytes.fromhex(r1["ct"]); T1=bytes.fromhex(r1["tag"])
C2=bytes.fromhex(r2["ct"]); T2=bytes.fromhex(r2["tag"])

# single-block, empty AAD:  T1^T2 = (C1^C2)*H^2  ->  H^2 = (T1^T2) * inv(C1^C2)
H2 = gcm.gf_mul(b2i(T1)^b2i(T2), gcm.gf_inv(b2i(C1)^b2i(C2)))
H  = gcm.gf_sqrt(H2)
S  = b2i(T1) ^ gcm.ghash(H, b"", C1)            # E_k(J0)

# forge a role=admin block; keystream is recoverable from a known pair
KS = bytes(a^b for a,b in zip(C1, p1))
pstar = b"role=admin;pad!!"                      # 16 bytes, contains 'admin'
Cstar = bytes(a^b for a,b in zip(pstar, KS))
Tstar = i2b(gcm.ghash(H, b"", Cstar) ^ S)
res = submit(nonce, Cstar, Tstar)
print(json.dumps(res))
PY
)"
echo "submit result: $OUT"
case "$OUT" in *"$FLAG"*) echo "h10 healthcheck rc=0"; exit 0 ;; esac
echo "h10 healthcheck FAILED"; exit 1
