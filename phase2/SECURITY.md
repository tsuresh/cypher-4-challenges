# Phase 2 — Security & DoS hardening

These challenges are **intentionally vulnerable**. This document covers the *unintended*
risks — DoS and blast-radius/cross-team leakage that would harm the event or the shared
infrastructure — and how they are contained. Code-level fixes are already in the repo; the
items marked **DEPLOY** must be enforced when the finals environment is stood up.

## Fixed in code (verified)

| Challenge | Risk | Fix |
|---|---|---|
| **i01, h01** SSRF | Pivot to CTFd / other containers / other teams' instances; OOM by fetching a huge file; redirect-to-internal bypass | App now allows **only** the metadata hosts, blocks all private/loopback/link-local/reserved targets (resolved-IP check), `allow_redirects=False`, and caps the response at 64 KB. Verified: metadata host works, `127.0.0.1`/RFC1918 refused. |
| **i02** XXE | Billion-laughs / exponential entity expansion → memory/CPU DoS | `huge_tree=False` (restores lxml's expansion limit), `no_network=True` (no external-DTD SSRF), `MAX_CONTENT_LENGTH=64 KB`. Verified: file-read XXE still solves; billion-laughs → HTTP 400 in 0 s, no OOM. |
| **m03, h10** oracles | Unbounded `bytes.fromhex` / huge GHASH input → memory/CPU DoS | Input length caps (`MAX_CONTENT_LENGTH`, per-field hex caps). Verified: both still solve. |
| **i04** pwn | `socat fork` with no limit → connection/fork-flood DoS | `max-children=48`; binary's own `alarm(60)` bounds each session; `pty` dropped. |
| **i05** K8s RBAC | Shared `records`/`apps` namespaces + `list` verb → a team could enumerate/read **other teams'** flag secrets | Per-team namespaces (`records-<team>`, `apps-<team>`); Role scoped to `get` on `resourceNames: [patient-vault]` only (no `list`, no enumeration). |

## DEPLOY — must be enforced when standing up the finals environment

### 1. Per-team container resource limits (all exploitable services)
Every whale-launched container (e02, i02, i04, m03, h06, h08, h10, i01, h01, h16) MUST run with
hard limits so one team's RCE/fork-bomb cannot take down the shared host:
```
--memory=256m --memory-swap=256m --pids-limit=128 --cpus=0.5 \
--read-only --tmpfs /tmp:size=16m   # where the app allows it
```
Set these in the ctfd-whale image config / compose. Without `--pids-limit`, an RCE challenge
(h06, h08) or the pwn service (i04) can fork-bomb the node.

### 2. Egress isolation (challenge containers)
Challenge containers must **not** reach CTFd, its DB/cache, each other, or the cloud metadata
server — with the sole exception of the SSRF VMs below. Put them on an isolated Docker network
with no route to the platform network (mirror Phase 1's `cypher-challenges` split), and block
`169.254.169.254` egress from every container except the SSRF challenges' dedicated VMs.

### 3. i01 / h01 SSRF — dedicated per-challenge VM, scoped SA (critical)
A container on a GCE VM reaches the **host VM's** metadata SA, not its own. If i01/h01 run as
containers on the shared finals VM, the SSRF leaks the **finals VM's** service-account token —
far beyond the intended scope. Each SSRF challenge MUST run on its **own small GCE VM** whose
attached SA is exactly the scoped challenge SA (i01: read one bucket object; h01:
`webhook-runner` starting the impersonation chain). The finals platform VM's own SA stays
powerless (as in Phase 1's `cypher-vm-runtime`). The in-app SSRF allowlist (fix above) still
lets the intended metadata read through.

### 4. h03 GKE — per-team node pool (cross-team flag leak)
The node SA is **cluster-wide**: every pod on a node can steal the same node token, so a single
shared node SA means all teams read the **same** secret (flag-sharing) and one team's node-SA
theft is not isolated from others. Give each team its **own node pool** with its own node SA
scoped to that team's unique secret, and pin the team's pod to it with a `nodeSelector`
(`cloud.google.com/gke-nodepool: team-<n>`). Keep the node SA minimal (secretAccessor on the one
secret only). Alternatively, run h03 as a genuinely per-team single-node cluster.

### 5. h16 container escape — nested throwaway sandbox (sharpest edge)
NEVER launch the h16 privileged container directly on the finals VM — the `release_agent` escape
would land as **root on the finals host** (CTFd DB, session key, all flags, and — if the VM SA
were privileged — the GCP project). Launch it inside a **nested throwaway sandbox** per team
(rootless-DinD / gVisor / a Firecracker microVM) that holds only `/flag`; a breakout reaches the
inner sandbox, never the finals VM or GCP. This is the Phase 1 DinD warning applied to an
*intentional* escape — treat it with the same care. Also apply the §1 resource limits (a
privileged container can still fork-bomb/disk-fill the sandbox).

### 6. h02 actAs — cloud cost/abuse guardrails
The deployer key can create Cloud Functions / Run services, i.e. arbitrary billable compute
(crypto-mining, egress). Contain it with: the sandbox **budget alert** (already set by
`gcp/bootstrap.sh`) plus, ideally, a **hard billing cap**; low **quotas** on Cloud Functions/Run
(max instances, CPU, timeout); an **Org Policy** restricting function regions/resources; and
monitoring/alerting on deploys during the event. The runtime SA (`ruhunu-core`) stays scoped to
the one secret, so data blast-radius is contained — the residual risk is spend, not data.

### 7. Firewall — restrict to the venue network (onsite finals)
`gcp/bootstrap.sh` opens the challenge port range and the whale/frp range to `0.0.0.0/0`. For
the **onsite** finals, restrict these to the venue/participant CIDR (a new `PHASE2_SOURCE_RANGES`
in `.env`), so the intentionally-vulnerable services are not exposed to the whole internet for
external DoS or unattended abuse. Keep SSH to `ADMIN_SOURCE_RANGES` (bootstrap already refuses
`0.0.0.0/0` there).

### 8. General
- **Least-privilege SAs** everywhere (already the design); the IAM healthchecks for
  h01/h02/h05/i01 assert scope limits — run them after provisioning.
- **Unique per-team flags** for shared challenges (`unique_flag`), so a leaked flag isn't
  reusable across teams.
- **Board freeze** and monitoring for solve anomalies (flag-sharing) during the event.
