# h12 — Serendib Machine (Pearl Telecom)

**Category:** Reverse Engineering / custom VM · **Difficulty:** Hard · **Points:** 400 (dynamic)

## Intended solve
The binary is a small **stack-based virtual machine**. A `main` dispatch loop reads a bytecode
program (embedded in `.rodata`) and validates the flag byte-by-byte through VM opcodes — not
native instructions — so a naive decompile shows only the interpreter, not the check.

1. Reverse the **dispatch loop** to recover the opcode table (PUSH, XOR, ADD, CMP, JMP, IN, …).
2. Dump the embedded bytecode program and disassemble it with the recovered opcodes.
3. The program transforms each input byte (e.g. `xor`/`add` with a rolling key) and compares to a
   constant table. Invert the transform over the constant table to recover the flag.

```python
# after lifting the bytecode:
target = [...]        # constants the VM compares against
key    = [...]        # from the VM program
flag = bytes((t ^ k) for t, k in zip(target, key))   # per the recovered op sequence
print(flag)          # CYPHER{...}
```

## Infra & safety
- **Attachment-only** static x86-64 binary (no live infra → low ops risk). The flag is not present
  as a literal string; it exists only as the inverse of the VM's constant table. Same flag for all
  teams (offline reversing; nothing to share live).

## Remediation (Blue Team Brief)
N/A as an app control — this is a reversing exercise. (Defensive framing for the brief: obfuscation
via a custom VM raises the bar but is not a secret-storage mechanism; never rely on client-side
checks or embedded constants to protect a secret.)
