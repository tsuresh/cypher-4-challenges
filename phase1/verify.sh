#!/usr/bin/env bash
# phase1/verify.sh — dry-solve every Phase 1 challenge via its healthcheck.
#
# Provisioning is split across two planes (DEPLOYMENT.md §1, §5) and so is
# verification, because the healthchecks are not all runnable in one place:
#
#   data plane  (02 03 04 05 08 09) — bound to localhost ports; VM only.
#   control plane (01 07 10 11)     — need project credentials (01, 10) or the
#                                     SA keys written at provision time (07, 11);
#                                     the hardened VM has neither, by design.
#   either      (06)                — anonymous HTTPS to storage.googleapis.com.
#   no infra    (00 12)             — nothing to check.
#
# This script detects which plane it is on and DEFERS what it cannot check,
# rather than reporting it as a failure. Exits non-zero only on a real failure;
# a run with deferred checks is NOT full coverage — run it on both hosts.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
CH="$REPO_ROOT/phase1/challenges"
export PHASE1_VM="${PHASE1_VM:-cypher-phase1}"

CONTROL_PLANE=" 01-open-warehouse 07-too-many-permissions 10-function-leak 11-the-escalation "
DATA_PLANE=" 02-leaked-ledger 03-forgotten-backup 04-metadata-mischief 05-git-happens 08-careless-container 09-peering-into-the-cluster "

HAVE_GCP_CREDS=0
if command -v gcloud >/dev/null 2>&1 \
   && timeout 45 gcloud projects describe "$GCP_PROJECT_ID" >/dev/null 2>&1; then
  HAVE_GCP_CREDS=1
fi

# The challenge VM is marked by vm-startup.sh; the port probe also covers a
# workstation running the compose stack locally. Deliberately NOT a pure port
# probe: on the VM a stopped stack must surface as FAIL, not as "deferred".
ON_DATA_PLANE=0
if [[ -f /opt/cypher/.startup-done ]]; then
  ON_DATA_PLANE=1
elif (exec 3<>/dev/tcp/127.0.0.1/8002) 2>/dev/null; then
  ON_DATA_PLANE=1
fi

pass=0; fail=0; skipped=0; deferred=0
for dir in "$CH"/*/; do
  name="$(basename "$dir")"
  hc="$dir/healthcheck.sh"
  if [[ ! -f "$hc" ]]; then
    printf '  %-32s %s\n' "$name" "— no healthcheck (no-infra)"; skipped=$((skipped+1)); continue
  fi
  if [[ $HAVE_GCP_CREDS -eq 0 && "$CONTROL_PLANE" == *" $name "* ]]; then
    printf '  %-32s %s\n' "$name" "— deferred: needs the admin host"; deferred=$((deferred+1)); continue
  fi
  if [[ $ON_DATA_PLANE -eq 0 && "$DATA_PLANE" == *" $name "* ]]; then
    printf '  %-32s %s\n' "$name" "— deferred: needs the challenge VM"; deferred=$((deferred+1)); continue
  fi
  if bash "$hc" >/tmp/hc.$$ 2>&1; then
    printf '  %-32s \033[0;32mPASS\033[0m\n' "$name"; pass=$((pass+1))
  else
    printf '  %-32s \033[0;31mFAIL\033[0m\n' "$name"; sed 's/^/      /' /tmp/hc.$$; fail=$((fail+1))
  fi
done
rm -f /tmp/hc.$$
echo
ok "verify: $pass passed, $fail failed, $skipped skipped, $deferred deferred"
if [[ $deferred -gt 0 ]]; then
  warn "$deferred check(s) deferred — this run is NOT full coverage."
  if [[ $HAVE_GCP_CREDS -eq 0 ]]; then
    warn "  no project credentials here: run verify.sh on the admin host for 01/07/10/11"
  fi
  if [[ $ON_DATA_PLANE -eq 0 ]]; then
    warn "  no challenge stack here: run verify.sh on cypher-phase1 for 02/03/04/05/08/09"
  fi
fi
[[ $fail -eq 0 ]]
