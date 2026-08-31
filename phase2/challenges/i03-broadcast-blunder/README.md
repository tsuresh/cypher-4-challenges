# i03 — Broadcast Blunder (Ruhunu Bank) 

**Category:** Crypto / RSA (Håstad broadcast) · **Difficulty:** Intermediate · **Points:** 300 (dynamic)

## Intended solve
The same message `m` (the flag) was RSA-encrypted with public exponent **e = 3** and sent to
three recipients with different moduli `n1, n2, n3`. No padding. With three ciphertexts and `e=3`,
combine by CRT then take an integer cube root.

```python
from sympy.ntheory.modular import crt
from gmpy2 import iroot
c = [c1, c2, c3]; n = [n1, n2, n3]
x, _ = crt(n, c)          # x ≡ m^3 (mod n1*n2*n3), and m^3 < n1*n2*n3
m, exact = iroot(int(x), 3)
assert exact
print(bytes.fromhex(hex(m)[2:]))   # CYPHER{...}
```
Detect the setup from the attached `capture.txt`: three `(n, e=3, c)` tuples, same plaintext.

## Infra & safety
- **Attachment-only** (`capture.txt`), shared with a per-team unique flag (the plaintext is that
  team's flag, re-encrypted per team at provision). No live service.
- `e=3` with no padding is the whole vulnerability; moduli are otherwise strong so factoring is
  not the path.

## Remediation (Blue Team Brief)
Never use textbook RSA — always pad (OAEP). Small exponents plus identical unpadded messages to
multiple recipients enable Håstad's broadcast attack; padding randomises each ciphertext.
