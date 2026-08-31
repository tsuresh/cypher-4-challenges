# m03 — Echo Chamber (Ruhunu Bank)

**Category:** Crypto / AES-ECB · **Difficulty:** Medium · **Points:** 250 (dynamic)

## Intended solve
The oracle returns `AES-ECB( your_input ‖ SECRET )` under a fixed, unknown key. ECB encrypts each
16-byte block independently, so identical plaintext blocks give identical ciphertext blocks —
recover `SECRET` (the flag) one byte at a time.

```python
# pseudo — byte-at-a-time ECB decryption
BS = 16
def oracle(data): ...            # returns hex ciphertext of data + SECRET
known = b""
while True:
    pad = b"A" * (BS - 1 - (len(known) % BS))              # align next unknown byte to a boundary
    target = oracle(pad)[: len(pad) + len(known) + 1 aligned to block]
    for b in range(256):
        if oracle(pad + known + bytes([b]))[block] == target:
            known += bytes([b]); break
# known -> CYPHER{...}
```

## Infra & safety
- Stateless encryption oracle (small service, **per-team instance**). Key is per-container and
  never leaves it; only ciphertext is returned. No padding-oracle side channel is needed.
- The flag is the appended `SECRET`; nothing else is reachable.

## Remediation (Blue Team Brief)
Never use ECB for anything structured — it leaks equality of blocks. Use an authenticated mode
(AES-GCM) with a unique nonce per message, and never encrypt attacker-controlled data prepended
to a secret under a deterministic mode.
