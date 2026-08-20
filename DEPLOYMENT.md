# CYPHER 4.0 — Production Deployment Runbook

How to take this repo from empty GCP to a live, public CTF. Read
[§1 Security model](#1-security-model--topology) before you provision anything —
it changes *where* you run the commands.

> Scope: Phase 1 (remote trials). Phase 2 (finals) reuses the same platform +
> ctfd-whale and is built manually — see [phase2/README.md](phase2/README.md).

---

## 0. Prerequisites

- A **GCP billing account** and permission to **create projects** and **link billing**
  (`roles/resourcemanager.projectCreator` + `roles/billing.admin`, or an org admin).
- `gcloud` + `gsutil` authenticated on an **admin host** (your laptop, a bastion,
  or Cloud Shell): `gcloud auth login`.
- Control of DNS for `BASE_DOMAIN` (to create the `ctfd.<domain>` A record).
- This repo cloned on the admin host, with `python3` + a venv holding `ctfcli`
  and `requests` (`python3 -m venv .venv && .venv/bin/pip install ctfcli requests`).

---

## 1. Security model & topology

The brief's hard rule: **least privilege everywhere, and the metadata-challenge
VM's service account must reach only its own flag.** That drives the topology.

```
┌── Admin host (you) ──────────────┐        ┌── Challenge VM (cypher-phase1) ──┐
│ gcloud / gsutil / ctf            │        │ Docker + kind ONLY               │
│ • bootstrap.sh                   │ SSH /  │ • CTFd + container challenges     │
│ • all GCP-native provisioning    │ gcloud │ • runs as cypher-vm-runtime SA    │
│   (buckets, secrets, functions,  │───────▶│   with NO project roles / scopes  │
│    IAM, the 04 metadata attr)    │        │ • so SSRF (chal 04) leaks a       │
│ • runs ctf challenge sync        │        │   POWERLESS token — safe          │
└──────────────────────────────────┘        └───────────────────────────────────┘
```

**Why the split:** the challenge VM hosts the SSRF challenge (04). If that VM
carries a privileged identity, solving 04 = project compromise. So the VM gets a
**no-privilege runtime SA**, and every `gcloud` action that *needs* privilege runs
from the **admin host**, never on the VM.

> ⚠️ **Current-code caveat.** `phase1/provision.sh` was written to run *on the VM*
> and does both Docker and `gcloud` provisioning there, which requires a
> privileged VM SA — fine for a lab, **not safe for a public event** because of
> challenge 04. For production, use the split below (control-plane vs data-plane).
> The maintainers can refactor `provision.sh` into `provision-cloud.sh` (admin
> host) + `provision-vm.sh` (VM) on request; until then, follow §5 manually.

---

## 2. Configure `.env` for production

```sh
cp .env.example .env
```
Set **real** values and, critically, generate every secret:

| Key | Production value |
|---|---|
| `GCP_PROJECT_ID` | a **brand-new, dedicated** sandbox project id |
| `GCP_BILLING_ACCOUNT_ID` | your billing account |
| `GCP_REGION` / `GCP_ZONE` | `asia-south1` / `asia-south1-a` |
| `BASE_DOMAIN` | e.g. `cypher.example.lk` |
| `ADMIN_SOURCE_RANGES` | your **real** admin egress CIDRs — never `0.0.0.0/0` |
| `ALERT_EMAIL` | inbox that must receive budget + ACME mail |
| `BUDGET_CAP_USD` | your hard cap |
| `CTFD_ADMIN_PASSWORD` | `openssl rand -base64 24` (do **not** reuse the local one) |
| `CTFD_SECRET_KEY` | `openssl rand -hex 32` |
| `CTFD_DB_PASSWORD` / `CTFD_DB_ROOT_PASSWORD` | `openssl rand -hex 24` each |
| `PHASE1_USE_SPOT` | `false` for the **live window** (Spot is fine only while building) |

`.env`, `.state/`, and `*-sa-key.json` are gitignored — keep them off git and
share secrets out-of-band.

---

## 3. Bootstrap the sandbox project (admin host)

```sh
./gcp/bootstrap.sh
```
Creates/links the project, enables APIs, sets the **budget alert**, builds the
locked-down VPC + firewall, and provisions the Phase-1 VM.

**Then, for production, lock down the VM identity** (until the split refactor lands):
```sh
# create a no-privilege runtime SA and move the VM onto it
gcloud iam service-accounts create cypher-vm-runtime \
  --project "$GCP_PROJECT_ID" --display-name "CYPHER challenge VM (no roles)"
gcloud compute instances set-service-account cypher-phase1 \
  --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID" \
  --service-account "cypher-vm-runtime@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --no-scopes                       # stop/start the VM for this to take effect
# and strip Editor from the default compute SA (belt & braces)
PNUM=$(gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)')
gcloud projects remove-iam-policy-binding "$GCP_PROJECT_ID" \
  --member "serviceAccount:${PNUM}-compute@developer.gserviceaccount.com" \
  --role roles/editor
```

**Verify the budget alert actually emails you** (trigger a low test threshold)
before go-live — an untested budget cap is not a cap.

---

## 4. DNS + TLS

Point DNS at the VM's external IP (printed by bootstrap):
```
A   ctfd.<BASE_DOMAIN>   ->   <phase1 VM external IP>
```
Caddy obtains a real Let's Encrypt cert automatically once the record resolves
and ports 80/443 are open (they are, per the firewall). No manual cert steps.

---

## 5. Deploy Phase 1 (split control plane / data plane)

Run §3's VM lock-down **first**. Once `cypher-phase1` is on `cypher-vm-runtime`
with `--no-scopes`, no `gcloud` call works from the VM — that is the whole point,
and it is why the steps below are split by *where* they run.

**Flags come first, on the admin host.** Three challenges bake their flag into a
container at `compose up` time (02, 03, 05) and two more are provisioned on the
VM (08, 09) — but *every* challenge is rendered and loaded into CTFd from the
admin host. Both planes must agree on the same values, so generate them once
here and carry them to the VM inside `.env`.

### 5a. Generate the flags (admin host)

```sh
bash <<'SH'
source shared/lib/common.sh; load_env; source shared/lib/flags.sh
gen() { make_flag "$1_$(random_token 4)"; }
cat >> .env <<EOF

# --- Phase 1 flags (generated $(date -u +%F)) --------------------------------
# FLAG_02/03/05 are consumed by docker compose on the VM; the rest are passed
# as CHAL_FLAG to each provisioner. .env is gitignored — keep it that way.
FLAG_01=$(gen warehouse)
FLAG_02=$(gen ledger)
FLAG_03=$(gen backup)
FLAG_04=$(gen metadata)
FLAG_05=$(gen githappens)
FLAG_06=$(gen signed)
FLAG_07=$(gen permissions)
FLAG_08=$(gen container)
FLAG_09=$(gen cluster)
FLAG_10=$(gen functionleak)
FLAG_11=$(gen escalation)
EOF
SH
```

### 5b. Data plane — on the VM (Docker + kind only, never `gcloud`)

```sh
# from the admin host
gcloud compute scp .env cypher-phase1:~/ --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID"
gcloud compute ssh cypher-phase1 --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID"

# on cypher-phase1
git clone <repo> cypher && cd cypher && mv ~/.env .
( cd phase1 && docker compose --env-file ../.env up -d --build \
    ctfd db cache proxy c02-leaked-ledger c03-forgotten-backup \
    c04-metadata-mischief c05-git-happens c08-dind )

set -a; . ./.env; set +a
CHAL_FLAG="$FLAG_08" bash phase1/challenges/08-careless-container/provision.sh
CHAL_FLAG="$FLAG_09" bash phase1/challenges/09-peering-into-the-cluster/setup-kind.sh
```

> Call 09's `setup-kind.sh` directly, **not** its `provision.sh`: the wrapper calls
> `vm_ip` (a `gcloud` call) only to print a CONNECT string, which a `--no-scopes`
> VM cannot do. The admin host supplies that string in §5d.

### 5c. Control plane — bootstrap CTFd over its API (admin host)

DNS must resolve and Caddy must hold its certificate first (§4). CTFd's port
8000 is bound to `127.0.0.1` on the VM, so the admin host can only reach it
through the public TLS endpoint.

```sh
curl -sS -o /dev/null -w '%{http_code}\n' "https://ctfd.$BASE_DOMAIN/"   # expect 200 or 302

set -a; . ./.env; set +a
export CTFD_URL="https://ctfd.$BASE_DOMAIN"
export CTFD_ADMIN_TOKEN="$(python3 shared/ctfd-base/bootstrap_ctfd.py \
  --url "$CTFD_URL" \
  --admin-user "$CTFD_ADMIN_USER" --admin-email "$CTFD_ADMIN_EMAIL" \
  --admin-pass "$CTFD_ADMIN_PASSWORD" \
  --ctf-name "CYPHER 4.0 — Recruitment Trials" \
  --scoreboard public)"
[ -n "$CTFD_ADMIN_TOKEN" ] || echo "CTFd bootstrap failed — stop here"
```

### 5d. Control plane — GCP challenges, then load all 13 into CTFd (admin host)

> ⚠️ **Do not use `shared/ctfcli/sync.sh` for this.** It walks `phase1/challenges/`,
> the *source* tree, whose `challenge.yml` files still carry the `__FLAG__`
> placeholder — it would publish 11 challenges whose accepted flag is the literal
> string `__FLAG__`, i.e. unsolvable and trivially "solvable" at the same time.
> `render_and_sync` substitutes the real flag into a gitignored build copy under
> `.state/build/` and installs *that*. Use it. (`sync.sh` is only safe against an
> already-rendered tree.)
>
> Order matters within this block: 07 and 11 write the SA-key files that ctfcli
> uploads as challenge attachments, so each provisioner must run before its own
> `render_and_sync` — which is what the loop does.

```sh
bash <<'SH'
source shared/lib/common.sh; load_env
source shared/lib/flags.sh; source shared/lib/gcp.sh; source shared/lib/render.sh
[[ -d .venv ]] && PATH="$PWD/.venv/bin:$PATH"
: "${CTFD_URL:?export CTFD_URL first — see 5c}"
: "${CTFD_ADMIN_TOKEN:?export CTFD_ADMIN_TOKEN first — see 5c}"
CH=phase1/challenges
IP="$(vm_ip cypher-phase1)"

# capture the CONNECT= line a provisioner prints as its last line
runp() { CHAL_FLAG="$2" bash "$1/provision.sh" 2>&1 | tee /dev/stderr | sed -n 's/^CONNECT=//p' | tail -1; }

# no infrastructure
render_and_sync "$CH/00-practice-range"  "CYPHER{welcome_to_cypher}" ""
render_and_sync "$CH/12-blue-team-brief" "n/a"                       ""

# already running on the VM (§5b) — connection info is just the VM IP + port
render_and_sync "$CH/02-leaked-ledger"            "$FLAG_02" "http://${IP}:8002/"
render_and_sync "$CH/03-forgotten-backup"         "$FLAG_03" "http://${IP}:8003/"
render_and_sync "$CH/05-git-happens"              "$FLAG_05" "http://${IP}:8005/"
render_and_sync "$CH/08-careless-container"       "$FLAG_08" "tcp://${IP}:8008"
render_and_sync "$CH/09-peering-into-the-cluster" "$FLAG_09" "https://${IP}:8009/  (Kubernetes Dashboard — click Skip)"

# GCP-native: provision from here (privileged), sync with the CONNECT it printed
for c in 01-open-warehouse 04-metadata-mischief 06-signed-and-sealed \
         07-too-many-permissions 10-function-leak 11-the-escalation; do
  eval "f=\$FLAG_${c%%-*}"
  render_and_sync "$CH/$c" "$f" "$(runp "$CH/$c" "$f")"
done
SH
```

Every flag that was actually installed is recorded in `.state/flags.csv`
(gitignored, mode 600) — that file is what `verify.sh` and the solve check read.

> The single-command `phase1/provision.sh` does all of §5 at once **on the VM**.
> Convenient for a lab, but it needs a privileged VM SA, which re-opens the
> challenge-04 hole §3 just closed. Do not use it for a public event.

## 6. Verify every solve path

On the VM (has all the local ports + kube context):
```sh
./phase1/verify.sh          # runs each challenge's healthcheck; non-zero on any fail
```
Confirm each flag registers on the public scoreboard by actually submitting one.

---

## 7. Go-live checklist

- [ ] `.env` has strong, unique secrets (admin, DB, `SECRET_KEY`); no defaults.
- [ ] VM runs `cypher-vm-runtime` (no roles / `--no-scopes`); default compute SA de-privileged.
- [ ] Each challenge SA is resource-scoped — `verify.sh` on 07/11 asserts it.
- [ ] `ADMIN_SOURCE_RANGES` is your real IPs; SSH is not world-open.
- [ ] Budget alert tested and delivered to `ALERT_EMAIL`.
- [ ] Live-window VM is **standard, not Spot**.
- [ ] TLS green on `https://ctfd.<domain>`; scoreboard reachable.
- [ ] No challenge accepts the literal `__FLAG__` — challenges were loaded via
      `render_and_sync` (§5d), never `shared/ctfcli/sync.sh` on the source tree.
- [ ] `verify.sh` fully green; a manual dry-solve of 00→11 done.
- [ ] DB volume snapshot / backup plan in place for the window.

---

## 8. During the event

- Public scoreboard at `https://ctfd.<domain>/scoreboard`.
- Hints are free (cost 0) — no action needed.
- First-blood bonuses are automatic (the `first_blood` plugin).
- Watch spend in the billing console against the cap.
- After the window: `./phase1/review-briefs.sh` for the Blue-Team tie-break.

---

## 9. Phase 2 (finals)

```sh
./gcp/bootstrap.sh --phase2-vm      # standard (non-Spot) e2-standard-8, refuses Spot
```
Then bring up CTFd + ctfd-whale + frp on the finals VM and load the mission +
standalone challenges. Set the scoreboard **freeze** (final 45 min) via
`bootstrap_ctfd.py --freeze-epoch <ts>`. Details in [phase2/README.md](phase2/README.md).

---

## 10. Teardown (leave nothing billable)

```sh
./phase1/teardown.sh        # challenge resources + containers
./gcp/teardown.sh           # VM(s), firewall, VPC, budget
# cleanest full wipe:
./gcp/teardown.sh --project # deletes the whole sandbox project
```
Confirm `gcloud compute instances list` is empty and billing flatlines.

---

## Appendix — hardening backlog

| Item | Status | Fix |
|---|---|---|
| VM identity leaks via chal 04 SSRF | **open (must-fix)** | split provisioning; `cypher-vm-runtime` no-roles SA (§3) |
| `provision.sh` couples control + data plane | open | refactor into `provision-cloud.sh` + `provision-vm.sh` |
| `sync.sh` publishes `__FLAG__` placeholders | **open (trap)** | it walks the *source* tree; only run it against a rendered tree — use `render_and_sync` (§5d) |
| DB / admin / session secrets | fixed | now in `.env.example`; generate per §2 |
| CTFd multi-worker `SECRET_KEY` | fixed | auto-generated + persisted by provision.sh |
| Egress from challenge workloads | partial | tighten VPC egress per challenge to what each solve needs |
| CTFd data durability | open | schedule pd snapshots of the CTFd DB volume |
