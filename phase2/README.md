# Phase 2 — Operation Serendib Shield (scaffold only)

> **Status:** directory scaffold in place; challenges are being built **manually**.
> Phase 1 is complete and is the reference implementation — mirror its patterns here.

## What's here
```
phase2/
  whale/            # ctfd-whale + frp config, per-team instance images  (TODO)
  mission/          # M1..M5 chained stages                              (TODO)
  standalone/       # S1..S6                                             (TODO)
  provision.sh      # (TODO) mirror phase1/provision.sh
  teardown.sh       # (TODO)
```

## Reuse from Phase 1
Everything under [shared/](../shared/) is phase-agnostic and ready to use:
- `shared/lib/{common,flags,gcp,render,healthcheck}.sh` — same helpers.
- `shared/ctfd-base/bootstrap_ctfd.py` — pass `--scoreboard public --freeze-epoch <ts>`
  for the finals board + the final-45-minute freeze.
- The challenge patterns map almost 1:1:
  - **M1 First Contact** ≈ pattern of 02/01 (exposed asset with creds)
  - **M2 Through the Door** ≈ 04 (SSRF → metadata token)
  - **M3 Climbing Higher** ≈ 11 (impersonation)
  - **M4 Into the Vault** ≈ 07/11 (elevated identity reads the secret/record)
  - **M5 Shut the Door** = objective flag + a planted persistence artifact to remove
  - **S1..S6** ≈ 06 / 10 / 11 / (container escape) / model endpoint / log analysis

## The one genuinely new piece: per-team isolation (ctfd-whale)
Mission stages and S2/S4/S5 are **per-team** via ctfd-whale + frp on the finals VM.
Provision the finals VM with `./gcp/bootstrap.sh --phase2-vm` (standard, non-Spot),
then bring up CTFd + whale + frp in `phase2/whale/`. Shared challenges (S1/S3/S6)
stay shared with per-team **unique flags** — `unique_flag <cid> <team>` in
`shared/lib/flags.sh` is already written for exactly this.

See [../CYPHER4_Phase2_Operation_Serendib_Shield.md](../CYPHER4_Phase2_Operation_Serendib_Shield.md)
for the full narrative, points, and hints.
