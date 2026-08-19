# 06 — Signed and Sealed (Arugam Waves)

**Category:** Cloud storage / access control · **Difficulty:** Medium · **Points:** 150 (dynamic)

## Intended solve
1. Given `…/receipts/CK-2026-0001.pdf`, notice the sequential naming.
2. `gsutil ls` fails (listing disabled) — so **enumerate the name** instead.
3. Fetch `…/receipts/CK-2026-0000.pdf` (the unlinked template) → `voucher code: CYPHER{...}`.

## Infra & safety
- Fine-grained-ACL bucket (`-b off`); receipt objects are individually
  `AllUsers:R` but **bucket listing is not granted** — the whole point.
- Flag lives in the `-0000` template object, uploaded from run-time `CHAL_FLAG`.

## Remediation (Blue Team Brief)
Use unguessable object names (UUIDs); prefer time-limited signed URLs over
public objects; don't rely on "no listing" as access control.
