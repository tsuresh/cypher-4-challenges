#!/usr/bin/env bash
# shared/ctfcli/sync.sh — install every challenge into CTFd from its challenge.yml.
# NOTHING is created by hand in the admin UI. Idempotent (ctfcli updates in place).
#
#   ./shared/ctfcli/sync.sh phase1
#   ./shared/ctfcli/sync.sh phase2
#
# Requires CTFD_URL and CTFD_ADMIN_TOKEN in the environment (phase provision.sh
# exports these after creating an admin API token).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared/lib/common.sh"
load_env
require ctfcli

PHASE="${1:?usage: sync.sh <phase1|phase2>}"
: "${CTFD_URL:?CTFD_URL must be set (phase provision.sh exports it)}"
: "${CTFD_ADMIN_TOKEN:?CTFD_ADMIN_TOKEN must be set}"

case "$PHASE" in
  phase1) ROOTS=("$REPO_ROOT/phase1/challenges") ;;
  phase2) ROOTS=("$REPO_ROOT/phase2/mission" "$REPO_ROOT/phase2/standalone") ;;
  *) die "Unknown phase: $PHASE" ;;
esac

# Point ctfcli at this CTFd instance (writes .ctf/config in CWD).
export CTFCLI_URL="$CTFD_URL"
export CTFCLI_ACCESS_TOKEN="$CTFD_ADMIN_TOKEN"
cd "$REPO_ROOT/$PHASE"
if [[ ! -f .ctf/config ]]; then
  mkdir -p .ctf
  cat > .ctf/config <<EOF
[config]
url = ${CTFD_URL}
access_token = ${CTFD_ADMIN_TOKEN}
EOF
fi

count=0
for root in "${ROOTS[@]}"; do
  while IFS= read -r -d '' yml; do
    dir="$(dirname "$yml")"
    name="$(basename "$dir")"
    step "Syncing challenge: $name"
    if ctfcli challenge install "$dir" >/dev/null 2>&1; then
      ok "installed $name"
    else
      ctfcli challenge sync "$dir" && ok "synced $name" || err "failed: $name"
    fi
    count=$((count+1))
  done < <(find "$root" -name challenge.yml -print0 | sort -z)
done

ok "Synced $count challenge(s) for $PHASE. Verify on the CTFd admin panel."
