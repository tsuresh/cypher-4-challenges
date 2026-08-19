#!/usr/bin/env bash
# 04 Metadata Mischief — plant the flag as a custom instance-metadata attribute
# on the phase-1 VM, reachable only via the metadata server (link-local).
# Expects CHAL_FLAG in the environment. Prints "CONNECT=<url>" on the last line.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

VM="${PHASE1_VM:-cypher-phase1}"
step "04: planting flag as instance metadata attribute cypher-flag-04 on $VM"
GC compute instances add-metadata "$VM" --zone "$GCP_ZONE" \
  --metadata "cypher-flag-04=${CHAL_FLAG}" --quiet
ok "04 metadata attribute set"

IP="$(vm_ip "$VM" 2>/dev/null || echo "<vm-ip>")"
echo "CONNECT=http://${IP}:8004/"
