#!/usr/bin/env bash
# h12 healthcheck / scripted solve: build the binary from a test flag, then solve
# it the intended way — extract the .vmcode bytecode from the ELF, interpret the
# opcodes, invert the transform to recover the flag, and confirm the binary
# accepts it. No knowledge of the flag is used by the solver.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{serendib_stack_machine_lifted}'
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
BIN="$HERE/serendib-machine"

# 1) build the challenge attachment
python3 "$HERE/src/gen.py" "$FLAG" > "$WORK/program.h"
gcc -O2 -no-pie -w -I"$WORK" -o "$BIN" "$HERE/src/vm.c"

# 2) SOLVE: pull the bytecode section out of the ELF and invert it
objcopy -O binary --only-section=.vmcode "$BIN" "$WORK/prog.bin"
RECOVERED="$(python3 - "$WORK/prog.bin" <<'PY'
import sys
prog=open(sys.argv[1],"rb").read()
PUSH,IN,XOR,ADD,CMP,HALT=1,2,3,4,5,6
ip=0; flag=bytearray()
# reconstruct each char from the opcode sequence: IN, PUSH k1, XOR, PUSH k2, ADD, PUSH t, CMP
while ip < len(prog) and prog[ip]!=HALT:
    assert prog[ip]==IN; ip+=1
    assert prog[ip]==PUSH; k1=prog[ip+1]; ip+=2
    assert prog[ip]==XOR; ip+=1
    assert prog[ip]==PUSH; k2=prog[ip+1]; ip+=2
    assert prog[ip]==ADD; ip+=1
    assert prog[ip]==PUSH; t=prog[ip+1]; ip+=2
    assert prog[ip]==CMP; ip+=1
    c=((t - k2) & 0xff) ^ k1      # invert ((c^k1)+k2)&0xff == t
    flag.append(c)
sys.stdout.write(flag.decode())
PY
)"
echo "recovered: $RECOVERED"

# 3) confirm the binary actually accepts the recovered key
OUT="$(printf '%s' "$RECOVERED" | "$BIN")"
echo "binary says: $OUT"
[[ "$RECOVERED" == "$FLAG" && "$OUT" == *"ACCESS GRANTED"* ]] && { echo "h12 healthcheck rc=0"; exit 0; }
echo "h12 healthcheck FAILED"; exit 1
