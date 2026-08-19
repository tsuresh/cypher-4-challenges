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

## 5. Deploy Phase 1

**Data plane — on the VM** (SSH from an admin range), Docker + kind only:
```sh
# on cypher-phase1
git clone <repo> cypher && cd cypher
scp/copy your .env here
cd phase1 && docker compose --env-file ../.env up -d --build \
  ctfd db cache proxy c02-leaked-ledger c03-forgotten-backup \
  c04-metadata-mischief c05-git-happens c08-dind
# challenge 09 (kind):
CHAL_FLAG=<gen> ./challenges/09-peering-into-the-cluster/provision.sh
```

**Control plane — from the admin host**, everything that needs `gcloud`:
```sh
# CTFd config over the API (admin, token, public scoreboard, freeze for finals)
python3 shared/ctfd-base/bootstrap_ctfd.py --url https://ctfd.<domain> …
# GCP-native challenges (creates resources in the project, not on the VM):
for c in 01-open-warehouse 06-signed-and-sealed 07-too-many-permissions \
         10-function-leak 11-the-escalation; do
  CHAL_FLAG=<gen> ./phase1/challenges/$c/provision.sh
done
# challenge 04's flag = a custom metadata attribute (set from here, not the VM):
CHAL_FLAG=<gen> ./phase1/challenges/04-metadata-mischief/provision.sh
# then load every challenge.yml into CTFd:
CTFD_URL=https://ctfd.<domain> CTFD_ADMIN_TOKEN=<token> ./shared/ctfcli/sync.sh phase1
```
> The single-command `phase1/provision.sh` does all of the above at once **on the
> VM** — convenient for a lab, but it needs a privileged VM SA. Use it only if you
> accept that trade-off; otherwise run the two planes separately as above.

---

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
| DB / admin / session secrets | fixed | now in `.env.example`; generate per §2 |
| CTFd multi-worker `SECRET_KEY` | fixed | auto-generated + persisted by provision.sh |
| Egress from challenge workloads | partial | tighten VPC egress per challenge to what each solve needs |
| CTFd data durability | open | schedule pd snapshots of the CTFd DB volume |
