# CYPHER 4.0 — Infrastructure and Leaderboard Build Brief
### For Claude Code (Google Cloud, Compute Engine)

This brief specifies the full build for both competition phases, running entirely on Google Cloud with Compute Engine as the host: the CTF platform, per-challenge infrastructure, per-team isolation, and the leaderboard. Build it as one repository with two deployable environments (`phase1`, `phase2`) sharing common tooling.

Also add these two files to the project for the full challenge narratives and flag intent:
- `CYPHER4_Phase1_Recruitment_Trials.md`
- `CYPHER4_Phase2_Operation_Serendib_Shield.md`

---

## Decisions to configure first

Set these at the top of a root `.env`. Everything runs on GCP in a dedicated sandbox project, hosted on Compute Engine.

```
CLOUD_TARGET=gcp
GCP_PROJECT_ID=cypher4-ctf-sandbox     # dedicated project, nothing else lives here
GCP_REGION=asia-south1                 # Mumbai, lowest latency to Sri Lanka (asia-southeast1 Singapore as alt)
GCP_ZONE=asia-south1-a
HOST=gce_vm                            # Compute Engine VM, confirmed. GKE is not used.
FINALS_ISOLATION=per_team              # ctfd-whale on the VM
BASE_DOMAIN=cypher.example.lk
FLAG_PREFIX=CYPHER
BUDGET_CAP_USD=200                     # hard budget alert on the sandbox project
```

The platform runs on Compute Engine VMs, not GKE. Per-team finals instances are handled by ctfd-whale on the VM. The one Kubernetes challenge (09) runs as a local kind cluster on the VM rather than on GKE, so there is no managed cluster to provision or pay for.

---

## Compute Engine host

Use two separate VMs so the finals run on a clean, larger machine and phase 1 does not have to be resized live.

| Setting | Phase 1 VM (remote trials) | Phase 2 VM (onsite finals) |
|---|---|---|
| Machine type | e2-standard-4 (4 vCPU, 16 GB) | e2-standard-8 (8 vCPU, 32 GB), scale to e2-standard-16 if load test shows pressure |
| OS image | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| Boot disk | 50 GB pd-balanced | 100 GB pd-ssd |
| Provisioning | Spot VM acceptable during build and testing | Standard VM for the live day, never Spot |

Reasoning: phase 1 is remote and jeopardy-style, so the VM mostly serves web and storage challenges while GCS and IAM run on GCP itself. Finals add ctfd-whale spinning up per-team containers for up to ten teams at once, plus the kind cluster, so it needs more headroom. Do not use a Spot VM for the finals, since a preemption during the live event would take the whole competition down.

**Networking and firewall**
- Allow inbound 80 and 443 for Caddy.
- Do not open SSH to the world. Restrict port 22 to admin source ranges, or use Identity-Aware Proxy.
- ctfd-whale exposes per-team containers through frp. Open the frp port range on the finals VM (for example 10000 to 10100) or route per-team instances under a wildcard subdomain.
- If using subdomain routing, point `*.${BASE_DOMAIN}` at the finals VM in Cloud DNS. Port routing is the simpler alternative and needs no wildcard record.
- Keep VPC egress from challenge workloads restricted to what each solve requires.

---

## Target stack

- One dedicated GCP project with billing budget alerts and a locked-down VPC.
- Two Compute Engine VMs (phase 1 and phase 2) running Docker and Docker Compose.
- Caddy as reverse proxy with automatic TLS (nginx acceptable if preferred).
- CTFd (official Docker image): teams, flag submission, dynamic scoring, native scoreboard, solve ordering.
- ctfcli for loading challenges as code, so nothing is created by hand in the admin UI.
- ctfd-whale on the finals VM for on-demand per-team instances, with frp for routing.
- kind (Kubernetes in Docker) on the VM for the single cluster challenge.
- GCP services for the cloud-native challenges: Cloud Storage (GCS), IAM and service accounts, Secret Manager, the GCP metadata server, and Cloud Functions or Cloud Run.
- Cloud DNS for `BASE_DOMAIN` (optional, needed only for whale subdomain routing).

---

## Repository layout

```
cypher4-infra/
  .env
  README.md
  gcp/
    bootstrap.sh         # create project resources: APIs, VPC, budget alert, service accounts, VMs
    teardown.sh          # remove all project resources
  shared/
    proxy/               # Caddy config and container
    ctfd-base/           # CTFd compose, plugins, theme
    ctfcli/              # ctfcli config, sync scripts
    lib/                 # reusable bash: gcloud helpers, VM provisioning, healthcheck, teardown
  phase1/
    docker-compose.yml   # CTFd + phase1 challenge services
    challenges/
      01-open-warehouse/
      02-leaked-ledger/
      03-forgotten-backup/
      04-metadata-mischief/
      05-git-happens/
      06-signed-and-sealed/
      07-too-many-permissions/
      08-careless-container/
      09-peering-into-the-cluster/
      10-function-leak/
      11-the-escalation/
      12-blue-team-brief/       # no infra, CTFd submission field only
    provision.sh
    teardown.sh
  phase2/
    docker-compose.yml   # CTFd + whale + mission + standalone services
    whale/               # ctfd-whale config, frp config, per-team instance images
    mission/
      stage1-first-contact/
      stage2-through-the-door/
      stage3-climbing-higher/
      stage4-into-the-vault/
      stage5-shut-the-door/
    standalone/
      s1-surfers-secret/
      s2-twelve-factor-slip/
      s3-role-reversal/
      s4-container-overboard/
      s5-model-in-the-middle/    # optional AI crossover
      s6-audit-trail/
    provision.sh
    teardown.sh
  leaderboard/
    display/             # optional themed big-screen mission board
```

Each challenge folder contains: a `challenge.yml` (ctfcli format), a `Dockerfile` or compose fragment for any service it runs, a flag injected at build or run time, a healthcheck, and a short `README` describing the intended solve. Flags follow `${FLAG_PREFIX}{...}`. GCP-backed challenges also carry a small provisioning script that creates and later destroys their GCP resources through `gcloud`.

---

## Challenge manifest

Infra type per challenge, mapped to GCP services. Narratives and intended techniques are in the two phase documents.

### Phase 1

| ID | Challenge | Infra to build | GCP service |
|---|---|---|---|
| 01 | Open Warehouse | Public bucket with a flag file | GCS bucket, allUsers read |
| 02 | Leaked Ledger | Site serving a reachable `.env` | Container on the VM or Cloud Run |
| 03 | Forgotten Backup | Web app with a guessable backup path | Container on the VM or Cloud Run |
| 04 | Metadata Mischief | SSRF app reaching the GCP metadata server | Container on a VM with a least-privilege service account |
| 05 | Git Happens | Web server exposing `.git` | Container on the VM or Cloud Run |
| 06 | Signed and Sealed | Enumerable signed URL or object name | GCS signed URLs |
| 07 | Too Many Permissions | Scoped SA whose role can read a secret | GCP IAM + Secret Manager |
| 08 | Careless Container | Exposed Docker API, list containers and read a container's env | Docker-in-Docker sandbox on the VM |
| 09 | Peering Into the Cluster | Anonymous-read Kubernetes secret | kind cluster on the VM |
| 10 | Function Leak | Serverless function leaking env vars | Cloud Functions or Cloud Run |
| 11 | The Escalation | Leaked SA key, enumerate, impersonate higher SA, read flag | GCP IAM + Secret Manager |
| 12 | Blue Team Brief | None. CTFd text submission, manual review | n/a |

### Phase 2

| ID | Item | Infra to build | Isolation |
|---|---|---|---|
| M1 | First Contact | Exposed asset serving low-priv creds | Per team |
| M2 | Through the Door | SSRF app reaching the GCP metadata server for a scoped SA token | Per team |
| M3 | Climbing Higher | IAM enumeration and service account impersonation | Per team |
| M4 | Into the Vault | Elevated SA reads a kind-cluster secret or a Cloud SQL record | Per team |
| M5 | Shut the Door | Objective flag plus a persistence artifact to remove | Per team |
| S1 | Surfer's Secret | Enumerable GCS signed URL or object name | Shared, unique flag |
| S2 | Twelve Factor Slip | Cloud Functions or Cloud Run env leak | Per team |
| S3 | Role Reversal | IAM misconfiguration privilege escalation | Shared, unique flag |
| S4 | Container Overboard | Container escape into a throwaway inner sandbox | Per team |
| S5 | Model in the Middle | Model-serving endpoint leaking config (optional) | Per team |
| S6 | Audit Trail | Bundle of Cloud Logging exports to trace | Shared, static |

The mission stages are chained: the token, key, or hint from one stage is what unlocks the next. Build them so stage N+1 is only reachable with what stage N reveals. On real GCP the metadata and IAM stages are authentic, so scope every service account so leaking it yields only the intended next step, never project-wide access.

---

## Leaderboard

Use CTFd's native scoreboard for both phases. Configure it, do not rebuild it.

- Dynamic scoring: use CTFd's dynamic challenge type. Set `initial`, `minimum`, and `decay` per challenge so value drops as more teams solve. Base values are in the phase documents.
- First blood: vanilla CTFd shows solve order but does not award bonus points. Implement first blood as a CTFd plugin or a small awards script that grants a fixed bonus to the first solver of each challenge. Keep it configurable.
- Tie-break: rank by points, then earliest last-accepted-solve time. This is CTFd default; confirm it is active.
- Freeze: set the scoreboard freeze time in CTFd config. For finals, freeze the public board for the final 45 minutes. Solves still count; the room stops seeing rank changes until the reveal.
- Visibility: public scoreboard during finals so it can be projected. Phase 1 scoreboard can be team-visible only if preferred.
- Hints: enable CTFd hints as free (zero cost) on every challenge and mission stage. The difficulty design depends on guided hints being available without a point penalty, so do not attach a point cost to them.

Optional finals big-screen display in `leaderboard/display/`: a read-only page that polls CTFd `GET /api/v1/scoreboard` and renders a themed mission status board. It must respect the freeze. Projecting CTFd's own `/scoreboard` is a valid fallback, so keep this optional.

---

## Isolation and safety on GCP (required)

- Everything lives in the dedicated sandbox project only. No shared credentials with any other project, and no access from the sandbox to the billing account or organisation resources.
- Set a hard budget alert at `BUDGET_CAP_USD` and confirm alerting works before the event.
- Every challenge service account is least-privilege and deny-by-default. A challenge that leaks a token or key must let it reach only that challenge's intended flag, never project admin. Test each one for over-broad access before go-live.
- The metadata-server challenges (04, M2) must run on a VM whose service account is scoped to the single secret or object that is the flag.
- The container-escape challenge (S4) must not escape onto the real Compute Engine host. Run it in a nested throwaway sandbox (Docker-in-Docker, or gVisor-isolated) so escaping the challenge lands in a disposable inner environment. Challenge 08 only reads a container's environment through an exposed Docker API and does not require a host escape, but still runs in the Docker-in-Docker sandbox.
- Restrict VPC egress from challenge workloads to what each solve requires.
- Finals per-team instances are time-limited and destroyed on session end or event close.
- `gcp/teardown.sh` and each phase `teardown.sh` leave nothing running or billable, including deleting the VMs. Verify the project is clean after a dry run.

---

## Build sequence

Build and verify in this order so each layer is testable before the next depends on it.

1. `gcp/bootstrap.sh`: create the sandbox project resources, enable APIs, set the budget alert, build the VPC and firewall rules, and provision the phase 1 Compute Engine VM. Confirm the budget alert fires on a test threshold.
2. Root `.env`, `shared/lib` gcloud helpers, Caddy proxy, CTFd base on the VM. Bring up CTFd, confirm admin access over TLS.
3. ctfcli wired to the CTFd instance. Confirm one test challenge syncs from `challenge.yml` with no manual UI steps.
4. Phase 1 storage and web challenges (01, 02, 03, 05). Validate the full pattern end to end, including flag capture on the scoreboard.
5. Phase 1 SSRF and metadata (04) against the real GCP metadata server with a scoped SA, and signed URL (06).
6. Phase 1 IAM challenges (07, 11) with least-privilege service accounts and Secret Manager. Verify no over-broad access.
7. Phase 1 container (08) in a nested sandbox, Kubernetes (09) on a kind cluster on the VM, serverless (10) on Cloud Functions or Cloud Run. Add the blue-team submission field (12).
8. Configure dynamic scoring, first blood, tie-break, and scoreboard for Phase 1. Run a full dry solve of every challenge.
9. Provision the larger phase 2 finals VM. Bring up a fresh CTFd plus ctfd-whale and frp. Confirm a per-team instance spins up and tears down on click, and is reachable through the frp port range or wildcard subdomain.
10. Phase 2 standalone challenges (S1 to S6).
11. Phase 2 mission chain M1 to M5, verifying each stage unlocks the next and every SA is correctly scoped.
12. Finals scoreboard, freeze time, and the optional big-screen display.
13. Load test on the finals VM: ten teams, concurrent per-team instances, plus the kind cluster. Confirm headroom and resize to e2-standard-16 if needed.

---

## Acceptance criteria

- The whole environment comes up on GCP from `gcp/bootstrap.sh` plus a single documented command per phase.
- Both Compute Engine VMs are provisioned by script, phase 1 on e2-standard-4 and finals on e2-standard-8 or larger, finals on a standard (non-Spot) VM.
- Every challenge is created only through ctfcli from its `challenge.yml`. No manual admin-UI creation.
- Every challenge has a verified solve path and its flag registers on the scoreboard.
- Every GCP service account is confirmed least-privilege and cannot reach beyond its intended flag.
- Dynamic scoring, first blood, tie-break, and freeze all behave as specified.
- Finals per-team instances provision and destroy cleanly through ctfd-whale, and the VM survives ten concurrent teams under load test.
- `gcp/teardown.sh` and each phase teardown leave the project clean and non-billable, VMs deleted.
- README documents bootstrap, bring-up, solve verification, and teardown.

---

## Notes for the agent

- One dedicated GCP project only. Do not touch any other project, production system, or the billing or organisation layer.
- Host is Compute Engine, not GKE. The only Kubernetes in the build is a local kind cluster on the VM for challenge 09.
- Keep flags out of source history where a challenge is not meant to leak them through git. Inject flags at build or run time, except where the challenge itself is a git-disclosure or env-leak challenge.
- Scope every service account to the minimum. On real GCP an over-broad role turns a single challenge into a project compromise, so this is the highest-risk item in the build.
- Prefer small, single-purpose workloads per challenge so one team breaking a challenge does not affect others.
- Everything must be reproducible from the repository. No undocumented manual steps.
