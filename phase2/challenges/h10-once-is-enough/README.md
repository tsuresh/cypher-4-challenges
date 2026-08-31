# h10 — Once Is Enough (Sethsuwa Health)

**Category:** Crypto / AES-GCM nonce reuse · **Difficulty:** Insane · **Points:** 500 (dynamic)

## Intended solve
The "secure note" service encrypts with **AES-GCM but a fixed nonce**. Two ciphertexts under the
same nonce break GCM's authentication (the **forbidden attack**): recover the auth key `H` and
forge a valid tag for a message you choose.

```python
# 1) Get two ciphertext+tag pairs under the same (fixed) nonce from the encrypt oracle.
# 2) In GF(2^128), the tag is a polynomial in H over the ciphertext blocks + lengths.
#    Two (C, T) pairs give an equation whose roots are candidate H (Sarkar/"forbidden attack").
#    Solve for H (factor the error polynomial; a handful of candidate roots).
# 3) With H known, compute the GHASH for a crafted ciphertext that decrypts to role=admin (flip
#    the keystream bits at the known plaintext offsets — keystream is recoverable since you know a
#    plaintext/ciphertext pair under this nonce), and forge the matching tag.
# 4) Submit the forged (nonce, ciphertext, tag): the server authenticates it and, seeing
#    role=admin, returns the flag.  ->  CYPHER{...}
```
References: Joux "forbidden attack" on GCM nonce reuse.

## Infra & safety
- Shared oracle service, **per-team unique flag**. Fixed nonce is the intended flaw. Server
  releases the flag only on a validly-tagged `role=admin` message, so a genuine forgery is
  required — not just decryption.

## Remediation (Blue Team Brief)
Never reuse a GCM nonce under one key — it is catastrophic (authentication forgery, not just
confidentiality). Use random 96-bit nonces with a counter/KMS, or a nonce-misuse-resistant mode
(AES-GCM-SIV). Rotate keys; treat nonce management as security-critical.

## Hint (costed, non-giveaway)
"GCM's one rule was broken; the tag is now forgeable." — cost 100.
