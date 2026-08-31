#!/usr/bin/env bash
# i03 healthcheck / scripted solve: generate the capture for a test flag, then
# solve it with Håstad's broadcast attack (CRT + integer cube root, pure Python)
# and confirm the recovered plaintext equals the flag.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{hastad_broadcast_e3_no_padding}'
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PY=""; [ -x "$HERE/../../../.venv/bin/python" ] && PY="$HERE/../../../.venv/bin/python" || PY=python3

"$PY" "$HERE/gen.py" "$FLAG" "$WORK/capture.txt" >/dev/null

REC="$("$PY" - "$WORK/capture.txt" <<'PY'
import re, sys
data=open(sys.argv[1]).read()
ns=[int(x,16) for x in re.findall(r'n = 0x([0-9a-f]+)', data)]
cs=[int(x,16) for x in re.findall(r'c = 0x([0-9a-f]+)', data)]
assert len(ns)==3 and len(cs)==3

def crt(rem, mod):
    from functools import reduce
    M=reduce(lambda a,b:a*b, mod)
    x=0
    for r,m in zip(rem,mod):
        Mi=M//m
        x += r*Mi*pow(Mi,-1,m)
    return x % M

def icbrt(x):
    if x<0: raise ValueError
    lo,hi=0,1<<((x.bit_length()//3)+2)
    while lo<hi:
        mid=(lo+hi)//2
        if mid**3<x: lo=mid+1
        else: hi=mid
    # lo**3>=x ; step back if overshoot
    while lo**3>x: lo-=1
    return lo

x=crt(cs, ns)              # x ≡ m^3 (mod n1 n2 n3), and m^3 < product
m=icbrt(x)
assert m**3==x, "not a perfect cube — attack setup wrong"
b=m.to_bytes((m.bit_length()+7)//8,'big')
sys.stdout.write(b.decode('latin1'))
PY
)"
echo "recovered: $REC"
[[ "$REC" == "$FLAG" ]] && { echo "i03 healthcheck rc=0"; exit 0; }
echo "i03 healthcheck FAILED"; exit 1
