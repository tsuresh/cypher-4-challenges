# 12 — Blue Team Brief (bonus)

**Category:** Written remediation · **Difficulty:** Bonus · **Points:** 100

No infrastructure — a CTFd text submission with **manual review**.

## How it works
- Teams submit a 3-sentence remediation brief in the flag field.
- A CTFd **regex flag** `(?s).{40,}` auto-accepts any substantial submission, so
  every genuine brief scores the 100-point bonus without a panel bottleneck.
- The SCTF panel then reads the stored submission text (via
  `phase1/review-briefs.sh`, which pulls `GET /api/v1/submissions`) and uses
  brief quality as the **secondary tie-break** described in the Phase 1 plan.

This keeps scoring automatic (no manual panel needed to produce the top-10 list)
while preserving the written brief as a differentiator.
