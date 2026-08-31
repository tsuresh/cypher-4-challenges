# Phase 2 finals — deployment runbook (admin)

Run this **on the finals VM `cypher-phase2`** (SSH is restricted to `ADMIN_SOURCE_RANGES`
= `34.10.219.19/32`; connect from an IP in that range). It brings up the finals CTFd +
ctfd-whale + frp, provisions the challenges, and loads them into the scoreboard.

Status when this runbook was written: the **6 cloud challenges are already provisioned**
into `cypher-p1` (e01, m01, h05, h02, h01, i01 — flags recorded in `.state/flags.csv`).
This runbook stands up the platform + the remaining container/static/GKE pieces.

## 0. Prerequisites (once, on the VM)
```sh
# repo + config + tools
git clone <this repo> ~/cypher && cd ~/cypher
cp /path/to/.env .env                      # the real .env (gitignored; carries secrets)
# the VM startup script already installed docker, compose, kind, kubectl
python3 -m venv .venv && . .venv/bin/activate && pip install ctfcli requests

# whale plugin (required for per-team instances)
git clone https://github.com/frankli0324/CTFd-Whale \
  shared/ctfd-base/plugins/ctfd_whale

# frp token/dashboard password into frps.ini (referenced by the whale settings)
sed -i "s/__FRP_TOKEN__/$(openssl rand -hex 16)/; s/__FRP_DASH_PWD__/$(openssl rand -hex 8)/" \
  phase2/whale/frps.ini
# add matching FRP_TOKEN=... to .env  (used by the whale plugin settings)
```

## 1. Provision (one command)
```sh
gcloud auth login                          # an account with access to cypher-p1
gcloud config set project cypher-p1
# optional: freeze the board for the final 30 min -> set the unix epoch of (end - 1800s)
# export PHASE2_FREEZE_EPOCH=$(date -d '2026-09-05 16:30:00 +0530' +%s)
./phase2/provision.sh                      # add PHASE2_GKE=1 to also do h03/i05 (needs a cluster+quota)
```
This: brings up CTFd+whale+frp, bootstraps CTFd (public board, freeze), builds the per-team
images, runs each challenge's `provision.sh` (cloud/static), and loads every `challenge.yml`
via ctfcli. Admin password is printed once — save it.

## 2. Configure ctfd-whale (per-team instances)
Follow `phase2/whale/WHALE.md`: set the docker socket, `cypher-p2-whale` network, frp
address/token, port range `10000-10100`, and register each whale challenge (dynamic_docker)
with its image + limits. Apply the per-container limits (mem/cpu/pids) from SECURITY.md §1.

## 3. Deploy the SSRF challenges on dedicated VMs (i01, h01)
Not whale (they'd leak the finals VM's SA). Create a small VM per challenge with the scoped SA:
```sh
gcloud compute instances create cypher-i01 --zone $GCP_ZONE --machine-type e2-small \
  --network cypher-vpc --subnet cypher-subnet --tags cypher-web \
  --service-account aperide-preview@cypher-p1.iam.gserviceaccount.com --scopes cloud-platform
# scp the repo / pull image cypher-p2/i01, then: docker run -d -p 8101:8000 cypher-p2/i01
# repeat for h01 with SA webhook-runner@... on :8001
```
Set each CTFd challenge's `connection_info` to `http://<that-vm-ip>:<port>/`. (Quota note: the
project's global vCPU quota is 12 — request an increase before adding many VMs / the GKE cluster.)

## 4. GKE challenges (h03, i05) — optional, needs quota
```sh
# raise CPUS_ALL_REGIONS quota first (12 is full), then:
TEAM=team01 CHAL_FLAG=... ./phase2/challenges/i05-namespace-nomad/provision.sh   # per team
PHASE2_GKE=1 ./phase2/provision.sh                                               # or via the orchestrator
```

## 5. Verify
```sh
./phase2/verify.sh                              # cloud + static, live
./phase2/challenges/verify-local.sh             # container/pwn/web, locally (build+solve)
# whale: click Launch on a challenge, solve the spawned instance
```

## 6. Go-live hardening (do BEFORE opening to teams)
- Restrict `cypher-allow-web` / `cypher-allow-challenges` / `cypher-allow-whale` source ranges
  from `0.0.0.0/0` to the **venue CIDR** (SECURITY.md §7).
- Apply per-container limits (SECURITY.md §1); confirm h16 runs in a nested sandbox (§5).
- Point DNS `ctfd.$BASE_DOMAIN` at the finals VM; confirm the board freeze time.

## 7. Teardown (after the event — stop billing)
```sh
./phase2/teardown.sh                                            # challenges + platform
gcloud compute instances delete cypher-phase2 cypher-phase2-b --zone $GCP_ZONE
```
