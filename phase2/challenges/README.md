# Phase 2 — Finals Challenge Pool ("Serendib Shield: Hard Track")

> **Status:** challenge **specs** (README + `challenge.yml`) authored here manually.
> Infra (Dockerfiles / `provision.sh` / `healthcheck.sh` / per-team whale images) is the **next**
> deliverable — each `challenge.yml` already carries `__FLAG__` / `__CONNECT__` placeholders so
> `shared/lib/render.sh` + ctfcli load them exactly like Phase 1.

A **flat pool of 20 hard, independent challenges** for the onsite finals (live, ~5 hours, ~10
teams of 4), released in **timed waves**, with **very limited hints**. This supersedes the
accessible chained mission in
[../../CYPHER4_Phase2_Operation_Serendib_Shield.md](../../CYPHER4_Phase2_Operation_Serendib_Shield.md);
the empty `phase2/{mission,standalone,whale}/` scaffolds are left untouched. Full rationale and
the trim/de-risk history: `~/.claude/plans/need-to-prepare-some-sparkling-heron.md`.

## Manifest (2 Easy · 2 Medium · 5 Intermediate · 6 Hard · 5 Insane)

Cloud: 7 · Web: 4 · Crypto: 3 · Rev: 1 · Pwn: 1 · Forensics: 2 · Container/K8s: 2
(≈45% cloud-flavoured once the GCP audit-log forensics and GKE/K8s items are counted).

| ID | Challenge | Company | Category | Diff | Pts | Wave | Isolation |
|----|-----------|---------|----------|------|-----|------|-----------|
| e01 | Bucket List | Arugam Waves | Cloud storage / recon | Easy | 200 | 1 | shared, unique flag |
| e02 | Client Side Story | Sethsuwa Health | Web / client-side secret | Easy | 200 | 1 | per-team instance |
| m01 | Overshared | Ceylon Kade | Cloud / allAuthenticatedUsers | Medium | 250 | 1 | shared, unique flag |
| m03 | Echo Chamber | Ruhunu Bank | Crypto / AES-ECB | Medium | 250 | 2 | per-team instance |
| i01 | Metadata Skim | Ape Ride | Cloud / SSRF→metadata token | Intermediate | 300 | 2 | per-team instance |
| i02 | Entity Crisis | LankaGov | Web / XXE | Intermediate | 300 | 1 | per-team instance |
| i03 | Broadcast Blunder | Ruhunu Bank | Crypto / RSA (Håstad) | Intermediate | 300 | 2 | shared, unique flag |
| i04 | Return to Sender | Pearl Telecom | Pwn / ret2win | Intermediate | 300 | 3 | per-team instance |
| i05 | Namespace Nomad | Sethsuwa Health | Container/K8s / RBAC | Intermediate | 300 | 3 | per-team instance |
| h03 | Off the Node | Pearl Telecom | Cloud / GKE Workload Identity | Hard | 400 | 3 | per-team namespace |
| h05 | State of Affairs | LankaGov | Cloud / Terraform state leak | Hard | 400 | 4 | shared, unique flag |
| h06 | Render Unto Ceylon | Ceylon Kade | Web / SSTI→RCE (WAF bypass) | Hard | 400 | 2 | per-team instance |
| h12 | Serendib Machine | Pearl Telecom | Rev / custom stack-VM | Hard | 400 | 3 | static attachment |
| h14 | Paper Trail | Ape Ride | Forensics / GCP Audit Logs | Hard | 400 | 1 | shared, unique flag |
| h15 | Quiet on the Wire | Sethsuwa Health | Forensics / pcap DNS-tunnel | Hard | 400 | 2 | static attachment |
| h01 | Token Relay | Ape Ride | Cloud / SSRF→impersonation chain | Insane | 500 | 4 | per-team instance |
| h02 | Deploy Your Privilege | Ruhunu Bank | Cloud IAM / actAs privesc | Insane | 500 | 4 | shared, unique flag |
| h08 | Polluted Pearls | Pearl Telecom | Web / prototype pollution→RCE | Insane | 500 | 4 | per-team instance |
| h10 | Once Is Enough | Sethsuwa Health | Crypto / AES-GCM nonce reuse | Insane | 500 | 3 | shared, unique flag |
| h16 | Overboard, Again | Pearl Telecom | Container escape / release_agent | Insane | 500 | 4 | per-team instance |

IDs are intentionally sparse (`m02`, `h04`, `h07`, `h09`, `h11`, `h13` were cut in the trim) — the
numbering is kept stable from the design draft so cross-references don't shift.

### AI Security bonus wave (ai1-ai3)

Three additional AI/LLM-security challenges, added after the trim, run alongside the 20 above —
not counted in the manifest/wave numbering. Each is a deterministic mock-LLM (regex-based, no
real model API calls) and deploys as a **shared instance** (one container for every team, like
e01/m01), not per-team whale:

| ID | Challenge | Company | Category | Diff | Pts | Isolation |
|----|-----------|---------|----------|------|-----|-----------|
| ai1 | Serendib Support Bot | Ape Ride | AI / prompt injection | Intermediate | 300 | shared instance |
| ai2 | Jailbreak the Concierge | Sethsuwa Health | AI / guardrail bypass | Hard | 400 | shared instance |
| ai3 | The Model in the Middle | Pearl Telecom | AI / indirect injection, tool abuse | Insane | 500 | shared instance |

Deployed via `phase2/challenges/ai{1,2,3}-*/provision.sh` (built by `build-images.sh`, verified
by `verify-local.sh`), same pattern as i01/h01.

## Release waves (~5-hour active window, board frozen for the final 30 min)

| Wave | Release T+ | Challenges |
|------|-----------|------------|
| 1 | 0:00 (open) | e01, e02, m01, i02, h14 |
| 2 | 1:15 | m03, i01, i03, h06, h15 |
| 3 | 2:30 | i04, i05, h03, h12, h10 |
| 4 | 3:30 | h05, h01, h02, h08, h16 |

Every wave (bar the finisher) opens with an Easy/Medium/Intermediate foothold beside its harder
drops; the five Insane challenges are back-loaded as the podium separators. In CTFd, gate release
by making later-wave challenges `state: hidden` until their wave (a scheduled visibility toggle),
or import per wave.

## Hint & scoring policy

- **Very limited hints.** Only the five Insane challenges may carry hints; four do (h01, h08, h10,
  h16), each a **single costed, non-giveaway** hint (`cost: 100`, ≈20–25% of value) that names the
  *class* of bug, never the payload. h02 and everything Hard-and-below ship **zero hints**.
  *Organizer's call:* time-gate those four (unlock ~75 min in) so the room keeps moving.
- **Dynamic scoring** per band: Easy `200/80/20`, Medium `250/100/15`, Intermediate `300/120/15`,
  Hard `400/150/12`, Insane `500/200/8` (`initial/minimum/decay`). First-blood bonus via the
  existing `first_blood` plugin. With ~10 teams, decay barely moves on the hard tier — first-blood
  + solve time decide the podium there, by design.

## Isolation

- **Per-team instance** (ctfd-whale): e02, m03, i01, i02, i04, i05, h06, h08, h16, h01, plus the
  per-team **namespace** on the shared finals GKE cluster for h03 (and i05 lives on the same
  cluster in its own namespace).
- **Shared, per-team unique flag** (`unique_flag <id> <team>` in `shared/lib/flags.sh`): e01, m01,
  i03, h05, h14, h02, h10.
- **Static attachment** (no live infra): i03, h12, h14, h15 (files listed in each `challenge.yml`).

## Security & DoS hardening

Full review in [../SECURITY.md](../SECURITY.md). In-code fixes (verified): SSRF allowlist +
response cap (i01/h01), XXE billion-laughs mitigation (i02), oracle input caps (m03/h10),
`socat max-children` (i04), per-team-namespaced RBAC (i05). Deploy-time musts: per-team
container resource limits (`--pids-limit`/`--memory`), egress isolation, i01/h01 on dedicated
scoped-SA VMs, h03 per-team node pool, h16 nested sandbox, venue-only firewall, h02 cost quotas.

## Safety notes carried into the build

- **h01** is **semi-blind** (the SSRF app reflects the fetched body) so token exfil is fair in-window.
- **h03** uses **one real small GKE cluster with per-team namespaces** (NetworkPolicy-isolated) —
  not per-team clusters, not a kind-faked metadata endpoint.
- **h16** must land its escape in a **nested throwaway sandbox** (rootless-DinD / gVisor / microVM,
  per the Phase 1 DinD warning) so a host escape can never reach the finals VM or the GCP project.
- Every GCP SA/role is least-privilege and resource-scoped; IAM healthchecks (as in Phase 1 07/11)
  assert the scope limits for h01/h02/h05/i01.

## Implementation & verification status

Every challenge now ships its infra (apps, Dockerfiles, binaries/generators, gcloud/k8s
provisioning) plus a `healthcheck.sh` that **is** the scripted solve. Run all local ones with
[`./verify-local.sh`](verify-local.sh).

- **Solve-verified locally (build → exploit → flag):** i03, i04, h12, m03, h10, h14, h15, e02,
  i02, h06, h08 — the exploit actually recovers the flag (crypto math, ret2win, VM lift, XXE,
  SSTI-WAF-bypass, prototype-pollution RCE, GCM forbidden-attack forgery, audit-log chain, DNS
  pcap). h10's GCM is validated against the NIST test vector.
- **Mechanic-verified locally:** i01, h01 (SSRF returns/reflects the fetched body — the metadata
  step is exercised in `LIVE=1` mode on the VM); h16 (container starts privileged with full
  `CapEff` + mount — the `release_agent` escape fires on the cgroup-v1 finals sandbox).
- **Code-complete, needs the live GCP/GKE sandbox to run:** e01, m01, h05, h02 (gcloud),
  h03, i05 (kubectl). Provisioning + healthchecks written against `shared/lib/gcp.sh`; all
  manifests/scripts pass offline validation. Their healthchecks run in the sandbox after
  `provision.sh`.

Generated per-team artifacts (binaries, `capture.*`, `audit-logs.tar.gz`, SA keys) are built at
provision time and **gitignored** — they never enter git, and the flag is never a literal in a
committed file.

## Build order (next deliverable)

1. `phase2/whale/` — ctfd-whale + frp on the finals VM (`./gcp/bootstrap.sh --phase2-vm`).
2. Per-challenge infra: Dockerfiles / `provision.sh` / `healthcheck.sh`, mirroring `phase1/`.
3. The finals GKE cluster for h03 + i05 (namespaces, RBAC, NetworkPolicy).
4. `phase2/provision.sh` + `teardown.sh` mirroring `phase1/`; CTFd bootstrap with
   `--scoreboard public --freeze-epoch <ts>`; wave-based visibility toggles.
