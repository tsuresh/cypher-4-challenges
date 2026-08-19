# CYPHER 4.0 — CTF Infrastructure

Infrastructure-as-code for the **CYPHER 4.0** cloud-security CTF, run by GDG Sri
Lanka / Women Techmakers (the *Serendib Cyber Task Force*). One repository, two
deployable environments (`phase1`, `phase2`) sharing common tooling, running
entirely on **Google Cloud with Compute Engine** as the host.

- **Phase 1 — The Recruitment Trials:** online, remote, jeopardy-style. 13
  challenges (00–12). **Complete and in this repo.**
- **Phase 2 — Operation Serendib Shield:** onsite finals, a chained 5-stage
  mission + 6 standalone challenges, per-team isolation via ctfd-whale.
  **Scaffolded — built manually (see [phase2/README.md](phase2/README.md)).**

The platform is CTFd (official image), challenges are loaded **as code** via
ctfcli (nothing created by hand in the admin UI), and every cloud-native
challenge is provisioned with `gcloud` against a **dedicated sandbox project**.

> ⚠️ These challenges are **intentionally vulnerable**. Run them only in the
> isolated sandbox project this repo provisions — never alongside anything else.

---

## Repository layout

```
.
├── .env.example            # copy to .env and fill in  (see "Configuration")
├── gcp/
│   ├── bootstrap.sh        # create project, APIs, budget alert, VPC/firewall, VM(s)
│   ├── vm-startup.sh        # GCE startup script: Docker, Compose, kind, kubectl
│   └── teardown.sh         # remove all project infra (or --project to wipe it all)
├── shared/
│   ├── proxy/Caddyfile     # automatic-TLS reverse proxy for CTFd
│   ├── ctfd-base/          # CTFd compose, first_blood plugin, API bootstrapper
│   ├── ctfcli/             # ctfcli config + sync helper
│   └── lib/                # reusable bash: common, gcp, flags, render, healthcheck
├── phase1/
│   ├── docker-compose.yml  # CTFd + proxy + container-backed challenges
│   ├── provision.sh        # one command to stand Phase 1 up end-to-end
│   ├── teardown.sh · verify.sh · review-briefs.sh
│   └── challenges/00-…/ … /12-…   # each: challenge.yml, infra, README, healthcheck
├── phase2/                 # scaffold — built manually
└── leaderboard/display/    # optional finals big-screen board (Phase 2)
```

Each challenge folder carries a `challenge.yml` (ctfcli format), any Dockerfile /
compose service or `provision.sh` it needs, a `healthcheck.sh`, and a `README.md`
describing the intended solve. **Flags are never committed** — `challenge.yml`
ships with an `__FLAG__` placeholder that `provision.sh` fills in at run time from
a generated flag (see [Flags & secrets](#flags--secrets)).

---

## Prerequisites

On your workstation (for bootstrap) and on the VM (for provisioning):

| Tool | Used for |
|---|---|
| `gcloud`, `gsutil` | all GCP provisioning |
| `docker`, `docker compose` | CTFd + container challenges |
| `ctfcli` | loading challenges as code (`pip install ctfcli`; the CLI command is `ctf`) |
| `python3` + `requests` | CTFd API bootstrap (`pip install requests`) |
| `kind`, `kubectl` | challenge 09 (installed on the VM by `vm-startup.sh`) |
| `curl`, `git` | healthchecks & helpers |

You must be authenticated (`gcloud auth login`) as a principal allowed to create
a project and link billing.

---

## Configuration

```sh
cp .env.example .env
$EDITOR .env
```

Key settings (full list in [.env.example](.env.example)):

| Variable | Meaning |
|---|---|
| `GCP_PROJECT_ID` | dedicated sandbox project — **nothing else lives here** |
| `GCP_BILLING_ACCOUNT_ID` | billing account to link + attach the budget to |
| `GCP_REGION` / `GCP_ZONE` | `asia-south1` (Mumbai) by default |
| `BUDGET_CAP_USD` | hard budget-alert threshold (default 200) |
| `ADMIN_SOURCE_RANGES` | CIDRs allowed to SSH — **never `0.0.0.0/0`** (bootstrap refuses it) |
| `BASE_DOMAIN` | e.g. `cypher.example.lk`; CTFd is served at `ctfd.$BASE_DOMAIN` |
| `FLAG_PREFIX` | flag wrapper, `CYPHER` → `CYPHER{...}` |
| `CTFD_ADMIN_*` | admin bootstrap creds (blank password → auto-generated, printed once) |

`.env`, generated SA keys (`*-sa-key.json`), and the flag registry are all
**gitignored**.

---

## Bring-up — Phase 1

Run in order; each layer is testable before the next depends on it.

### 1. Bootstrap the sandbox project + Phase-1 VM
```sh
./gcp/bootstrap.sh
```
Creates/links the project, enables APIs, sets the **budget alert** (verify it
actually emails you before go-live), builds the locked-down VPC + firewall
(web 80/443 to the world, SSH to admin ranges only, challenge ports 8000–8099),
and provisions the `cypher-phase1` VM (`e2-standard-4`, Ubuntu 22.04). The VM's
startup script installs Docker, Compose, kind, and kubectl.

Point DNS: `A  ctfd.$BASE_DOMAIN → <phase1 VM external IP>` (printed at the end).

### 2. Provision everything on the VM
SSH to the VM (from an admin range), clone this repo, copy your `.env`, then:
```sh
./phase1/provision.sh
```
This single command:
1. generates a fresh flag per challenge (written to `.state/flags.csv`, gitignored),
2. brings up CTFd + proxy + container challenges (`docker compose up -d --build`),
3. bootstraps CTFd over its API — admin user, API token, **public scoreboard**,
   scoring config (no manual UI steps),
4. provisions the GCP-native (01, 06, 07, 10, 11), kind (09), and DinD (08)
   challenges via `gcloud`/`kind`/`docker`,
5. renders each `challenge.yml` with its flag + connection info and loads it via
   **ctfcli**,
6. prints a summary (scoreboard URL, admin login, flag-registry path).

CTFd is now public at `https://ctfd.$BASE_DOMAIN`.

### 3. Verify every solve path
```sh
./phase1/verify.sh          # runs each challenge's healthcheck; non-zero on any failure
```

### 4. (After the window) review Blue Team briefs for the tie-break
```sh
export CTFD_ADMIN_TOKEN=…   # printed by provision.sh
./phase1/review-briefs.sh
```

---

## Phase 1 challenge manifest

| ID | Challenge | Category | Diff | Pts | Where / how to solve |
|----|-----------|----------|------|-----|----------------------|
| 00 | Practice Range | Warm-up | Trivial | 10 | submit `CYPHER{welcome_to_cypher}` |
| 01 | The Open Warehouse | Cloud storage | Easy | 75 | `gsutil ls -r gs://<proj>-ck-warehouse` |
| 02 | Leaked Ledger | Web / secrets | Easy | 75 | `:8002/.env` |
| 03 | The Forgotten Backup | Web / recon | Easy | 100 | `:8003/backups/db_backup.sql` |
| 05 | Git Happens | Web / source disclosure | Easy | 100 | `:8005/.git/` → `git log -p` |
| 04 | Metadata Mischief | SSRF / metadata | Medium | 150 | `:8004` SSRF → `169.254.169.254/…/cypher-flag-04` |
| 06 | Signed and Sealed | Cloud storage | Medium | 150 | enumerate object name `…-0000.pdf` |
| 07 | Too Many Permissions | Cloud IAM | Medium | 150 | attached SA key → read secret |
| 10 | Function Leak | Serverless | Medium | 150 | `?template={env}` on the function URL |
| 09 | Peering Into the Cluster | Kubernetes | Medium | 175 | `:8009` dashboard → Skip → read Secret |
| 08 | The Careless Container | Container | Medium | 200 | `DOCKER_HOST=tcp://vm:8008 docker ps` |
| 11 | The Escalation | IAM priv-esc | Hard | 300 | leaked key → impersonate → read secret |
| 12 | Blue Team Brief | Written (bonus) | Bonus | 100 | submit a 3-sentence remediation |

`:PORT` means `http://<phase1 VM external IP>:PORT/`. Ports 8000–8099 are opened
by `gcp/bootstrap.sh`. Every challenge also carries a **free hint** (zero cost).

---

## Scoring & leaderboard

Uses CTFd's **native** scoreboard — configured, not rebuilt.

- **Dynamic scoring** — every challenge (except the warm-up) is `type: dynamic`
  with `initial`/`minimum`/`decay` set in its `challenge.yml`, so value drops as
  more teams solve. Base values match the Phase 1 plan.
- **First blood** — the [`first_blood`](shared/ctfd-base/plugins/first_blood)
  plugin grants a fixed bonus (`FIRST_BLOOD_BONUS`, default 50) to the first
  solver of each challenge. Vanilla CTFd shows solve order but awards no bonus.
- **Free hints** — every hint is `cost: 0`. The difficulty design depends on
  guided hints being free, so nothing is ever penalised.
- **Tie-break** — CTFd default (points, then earliest last-accepted solve); the
  Blue Team Brief is the documented secondary tie-break.
- **Freeze** — a finals concern (Phase 2): pass `--freeze-epoch` to the CTFd
  bootstrapper to freeze the public board for the final 45 minutes.

An optional themed big-screen board lives in `leaderboard/display/` (Phase 2);
projecting CTFd's own `/scoreboard` is the fallback.

---

## Flags & secrets

- Flags follow `${FLAG_PREFIX}{...}` and are **generated at provision time**, never
  committed. `challenge.yml` ships with an `__FLAG__` placeholder; `render.sh`
  substitutes the real flag into a **gitignored build copy** that ctfcli installs.
- The exceptions are challenges whose whole point is a leak: **05 Git Happens**
  (flag in `.git` history) and **10 Function Leak** (flag in the function env) —
  there the flag is injected into the running artifact at start, still from a
  run-time value, so it never touches this repo's history.
- Generated SA keys are handed to teams as challenge attachments and are
  gitignored (`*-sa-key.json`).

---

## Isolation & safety (required, and enforced)

- Everything lives in the **one dedicated sandbox project**. `gcloud` wrappers in
  `shared/lib/gcp.sh` pin `--project` on every call so a mis-set default cannot
  touch another project.
- A **hard budget alert** at `BUDGET_CAP_USD` is created at bootstrap.
- Every challenge service account is **least-privilege, resource-scoped**. A leak
  reaches only that challenge's intended flag — never project admin. The IAM
  healthchecks (07, 11) actively assert the SA **cannot** exceed its scope.
- The metadata challenge (04) plants its flag as a **custom instance-metadata
  attribute** on a VM whose SA is scoped to nothing project-wide.
- The container challenge (08) exposes its Docker API inside a throwaway
  **Docker-in-Docker sandbox** — a breakout lands in the DinD, never on the host.
- SSH is restricted to `ADMIN_SOURCE_RANGES`; bootstrap refuses `0.0.0.0/0`.

---

## Teardown — leave nothing billable

```sh
./phase1/teardown.sh        # remove challenge resources + stop containers (per-challenge teardowns)
./gcp/teardown.sh           # delete VM(s), firewall, VPC, budget
# or, the cleanest wipe:
./gcp/teardown.sh --project # delete the entire sandbox project
```
After teardown, `gcloud compute instances list` should be empty and the project
non-billable.

---

## Acceptance checklist (Phase 1)

- [x] Whole environment comes up from `gcp/bootstrap.sh` + one command (`phase1/provision.sh`).
- [x] VM provisioned by script (`e2-standard-4`); finals VM path (`--phase2-vm`, standard/non-Spot) ready.
- [x] Every challenge created **only** through ctfcli from its `challenge.yml`.
- [x] Every challenge has a scripted solve path (`verify.sh` / per-challenge `healthcheck.sh`).
- [x] Service accounts are least-privilege; 07/11 healthchecks assert scope limits.
- [x] Dynamic scoring, first blood, tie-break, and free hints configured.
- [x] `teardown` scripts leave the project clean and non-billable.
- [x] README documents bootstrap, bring-up, solve verification, and teardown.

---

## Documents

- [CYPHER4_Infra_Leaderboard_Build_Brief.md](CYPHER4_Infra_Leaderboard_Build_Brief.md) — the build brief this repo implements
- [CYPHER4_Phase1_Recruitment_Trials.md](CYPHER4_Phase1_Recruitment_Trials.md) — Phase 1 narrative, points, hints
- [CYPHER4_Phase2_Operation_Serendib_Shield.md](CYPHER4_Phase2_Operation_Serendib_Shield.md) — Phase 2 narrative (built manually)
