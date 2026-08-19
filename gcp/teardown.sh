#!/usr/bin/env bash
# gcp/teardown.sh — remove ALL sandbox project resources. Leaves nothing billable.
#
#   ./gcp/teardown.sh            # tear down VMs, network, budget (keeps empty project)
#   ./gcp/teardown.sh --project  # ALSO delete the whole project (nuclear, cleanest)
#   ASSUME_YES=1 ./gcp/teardown.sh
#
# Per-challenge GCP resources (SAs, secrets, buckets, functions) are removed by
# the phase teardown scripts; run those first, or use --project to wipe everything.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
require gcloud

FULL_PROJECT=0
[[ "${1:-}" == "--project" ]] && FULL_PROJECT=1

warn "This DESTROYS resources in project: $GCP_PROJECT_ID"
confirm "Tear down CYPHER4 infrastructure now?" || die "Aborted."

if [[ $FULL_PROJECT -eq 1 ]]; then
  step "Deleting entire project $GCP_PROJECT_ID"
  confirm "FULL PROJECT DELETE of '$GCP_PROJECT_ID'. This is irreversible. Sure?" || die "Aborted."
  gcloud projects delete "$GCP_PROJECT_ID" --quiet
  ok "Project scheduled for deletion. Nothing remains billable."
  exit 0
fi

# --- Delete VMs ------------------------------------------------------------
for vm in cypher-phase1 cypher-phase2; do
  if vm_exists "$vm"; then
    step "Deleting VM $vm"
    GC compute instances delete "$vm" --zone "$GCP_ZONE" --quiet || true
  fi
done

# --- Firewall + network ----------------------------------------------------
for fw in cypher-allow-web cypher-allow-ssh-admin cypher-allow-whale cypher-allow-challenges; do
  GC compute firewall-rules delete "$fw" --quiet 2>/dev/null || true
done
GC compute networks subnets delete cypher-subnet --region "$GCP_REGION" --quiet 2>/dev/null || true
GC compute networks delete cypher-vpc --quiet 2>/dev/null || true

# --- Budget ----------------------------------------------------------------
if [[ -n "${GCP_BILLING_ACCOUNT_ID:-}" ]]; then
  bid="$(gcloud billing budgets list --billing-account "$GCP_BILLING_ACCOUNT_ID" \
    --filter='displayName=cypher4-cap' --format='value(name)' 2>/dev/null || true)"
  [[ -n "$bid" ]] && gcloud billing budgets delete "$bid" --quiet 2>/dev/null || true
fi

step "Verifying no compute instances remain"
remaining="$(GC compute instances list --format='value(name)' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$remaining" == "0" ]]; then
  ok "No instances remain. Run phase teardown scripts (or --project) to remove challenge resources."
else
  warn "$remaining instance(s) still present — inspect with: gcloud compute instances list"
fi
