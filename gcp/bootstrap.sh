#!/usr/bin/env bash
# gcp/bootstrap.sh — one-time sandbox project bootstrap.
#
# Creates/uses the dedicated sandbox project, links billing, enables APIs,
# sets a HARD budget alert, builds a locked-down VPC + firewall, and provisions
# the phase-1 Compute Engine VM. Idempotent: safe to re-run.
#
#   ./gcp/bootstrap.sh                 # full bootstrap (phase 1 VM)
#   ./gcp/bootstrap.sh --phase2-vm     # also provision the finals VM
#   ASSUME_YES=1 ./gcp/bootstrap.sh    # non-interactive
#
# Requires: gcloud (authenticated as a user who can create projects & link billing).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
require gcloud gsutil curl

WANT_PHASE2_VM=0
[[ "${1:-}" == "--phase2-vm" ]] && WANT_PHASE2_VM=1

: "${GCP_BILLING_ACCOUNT_ID:?Set GCP_BILLING_ACCOUNT_ID in .env}"
: "${ADMIN_SOURCE_RANGES:?Set ADMIN_SOURCE_RANGES in .env (never 0.0.0.0/0)}"
[[ "$ADMIN_SOURCE_RANGES" == *"0.0.0.0/0"* ]] && die "Refusing: ADMIN_SOURCE_RANGES contains 0.0.0.0/0"

NETWORK="cypher-vpc"
SUBNET="cypher-subnet"
SUBNET_CIDR="10.10.0.0/24"

step "Bootstrapping sandbox project: $GCP_PROJECT_ID"
confirm "This creates/links billing on project '$GCP_PROJECT_ID' and provisions a VM. Continue?" \
  || die "Aborted."

# --- 1. Project ------------------------------------------------------------
if ! gcloud projects describe "$GCP_PROJECT_ID" >/dev/null 2>&1; then
  log "Creating project $GCP_PROJECT_ID"
  gcloud projects create "$GCP_PROJECT_ID" --name "CYPHER4 CTF Sandbox" --quiet
else
  ok "Project already exists"
fi

log "Linking billing account $GCP_BILLING_ACCOUNT_ID"
gcloud billing projects link "$GCP_PROJECT_ID" \
  --billing-account "$GCP_BILLING_ACCOUNT_ID" --quiet

# --- 2. APIs ---------------------------------------------------------------
ensure_apis \
  compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com \
  cloudfunctions.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  logging.googleapis.com \
  dns.googleapis.com \
  billingbudgets.googleapis.com \
  cloudresourcemanager.googleapis.com

# --- 3. Budget alert (HARD guard) ------------------------------------------
step "Configuring budget alert at \$${BUDGET_CAP_USD}"
BILLING_ACCT="$GCP_BILLING_ACCOUNT_ID"
if ! gcloud billing budgets list --billing-account "$BILLING_ACCT" \
      --format='value(displayName)' 2>/dev/null | grep -q '^cypher4-cap$'; then
  gcloud billing budgets create \
    --billing-account "$BILLING_ACCT" \
    --display-name "cypher4-cap" \
    --budget-amount "${BUDGET_CAP_USD}USD" \
    --filter-projects "projects/$GCP_PROJECT_ID" \
    --threshold-rule=percent=0.5 \
    --threshold-rule=percent=0.9 \
    --threshold-rule=percent=1.0 \
    --quiet
  ok "Budget 'cypher4-cap' created (alerts at 50/90/100%)"
else
  ok "Budget already configured"
fi
warn "Verify the budget alert actually emails ${ALERT_EMAIL:-your admin} BEFORE go-live."

# --- 4. Network (locked-down VPC) ------------------------------------------
step "Building VPC $NETWORK"
if ! GC compute networks describe "$NETWORK" >/dev/null 2>&1; then
  GC compute networks create "$NETWORK" --subnet-mode=custom --quiet
fi
if ! GC compute networks subnets describe "$SUBNET" --region "$GCP_REGION" >/dev/null 2>&1; then
  GC compute networks subnets create "$SUBNET" \
    --network "$NETWORK" --region "$GCP_REGION" --range "$SUBNET_CIDR" --quiet
fi

# Firewall: web open to world, SSH only to admin ranges, whale range on finals.
_fw() { GC compute firewall-rules describe "$1" >/dev/null 2>&1; }

_fw cypher-allow-web || GC compute firewall-rules create cypher-allow-web \
  --network "$NETWORK" --allow tcp:80,tcp:443 \
  --source-ranges 0.0.0.0/0 --target-tags cypher-web --quiet

_fw cypher-allow-ssh-admin || GC compute firewall-rules create cypher-allow-ssh-admin \
  --network "$NETWORK" --allow tcp:22 \
  --source-ranges "$ADMIN_SOURCE_RANGES" --target-tags cypher-ssh --quiet

_fw cypher-allow-whale || GC compute firewall-rules create cypher-allow-whale \
  --network "$NETWORK" --allow "tcp:${FRP_PORT_RANGE_START}-${FRP_PORT_RANGE_END}" \
  --source-ranges 0.0.0.0/0 --target-tags cypher-whale --quiet

# Per-challenge web services published on the 8000-8099 range (phase 1 remote).
_fw cypher-allow-challenges || GC compute firewall-rules create cypher-allow-challenges \
  --network "$NETWORK" --allow tcp:8000-8099 \
  --source-ranges 0.0.0.0/0 --target-tags cypher-web --quiet

# Deny-by-default egress except essentials is enforced per-workload; the VPC
# keeps default egress but challenge workloads restrict it (see per-challenge notes).
ok "Firewall rules in place (web:world, ssh:admin-only, whale:range)"

# --- 5. Phase-1 VM ---------------------------------------------------------
provision_vm() {
  local name="$1" machine="$2" disk_gb="$3" disk_type="$4" use_spot="$5" extra_tags="$6"
  if vm_exists "$name"; then ok "VM $name already exists"; return; fi
  local spot_args=()
  [[ "$use_spot" == "true" ]] && spot_args=(--provisioning-model=SPOT --instance-termination-action=STOP)
  step "Provisioning VM $name ($machine, ${disk_gb}GB ${disk_type}, spot=$use_spot)"
  GC compute instances create "$name" \
    --zone "$GCP_ZONE" \
    --machine-type "$machine" \
    --image-family ubuntu-2204-lts --image-project ubuntu-os-cloud \
    --boot-disk-size "${disk_gb}GB" --boot-disk-type "$disk_type" \
    --network "$NETWORK" --subnet "$SUBNET" \
    --tags "cypher-web,cypher-ssh,${extra_tags}" \
    --metadata-from-file startup-script="$REPO_ROOT/gcp/vm-startup.sh" \
    --scopes cloud-platform \
    "${spot_args[@]}" \
    --quiet
  ok "VM $name created; startup-script installs Docker + Compose. External IP: $(vm_ip "$name")"
}

provision_vm "cypher-phase1" "$PHASE1_MACHINE_TYPE" "$PHASE1_BOOT_DISK_GB" \
  "$PHASE1_BOOT_DISK_TYPE" "$PHASE1_USE_SPOT" "cypher-phase1"

if [[ $WANT_PHASE2_VM -eq 1 ]]; then
  [[ "$PHASE2_USE_SPOT" == "false" ]] || die "Refusing: finals VM must not be Spot (set PHASE2_USE_SPOT=false)."
  provision_vm "cypher-phase2" "$PHASE2_MACHINE_TYPE" "$PHASE2_BOOT_DISK_GB" \
    "$PHASE2_BOOT_DISK_TYPE" "$PHASE2_USE_SPOT" "cypher-whale,cypher-phase2"
fi

step "Bootstrap complete"
ok "Phase-1 VM external IP: $(vm_ip cypher-phase1 2>/dev/null || echo '<pending>')"
cat <<EOF

Next steps:
  1. Point DNS: A record  ctfd.${BASE_DOMAIN}  ->  $(vm_ip cypher-phase1 2>/dev/null || echo '<phase1-ip>')
  2. SSH in (from an admin range) and clone this repo, or use shared/lib/deploy.sh
  3. Run:  ./phase1/provision.sh
EOF
