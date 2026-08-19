#!/usr/bin/env bash
# 09 provision wrapper — builds the cluster and prints CONNECT.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAL_FLAG="$CHAL_FLAG" bash "$HERE/setup-kind.sh"
IP="$(vm_ip "${PHASE1_VM:-cypher-phase1}" 2>/dev/null || echo '<vm-ip>')"
echo "CONNECT=https://${IP}:8009/  (Kubernetes Dashboard — click Skip)"
