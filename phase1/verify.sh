#!/usr/bin/env bash
# phase1/verify.sh — dry-solve every Phase 1 challenge via its healthcheck.
# Run ON the phase-1 VM after provision.sh. Exits non-zero if any check fails.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
CH="$REPO_ROOT/phase1/challenges"
export PHASE1_VM="${PHASE1_VM:-cypher-phase1}"

pass=0; fail=0; skipped=0
for dir in "$CH"/*/; do
  name="$(basename "$dir")"
  hc="$dir/healthcheck.sh"
  if [[ ! -f "$hc" ]]; then
    printf '  %-32s %s\n' "$name" "— no healthcheck (no-infra)"; skipped=$((skipped+1)); continue
  fi
  if bash "$hc" >/tmp/hc.$$ 2>&1; then
    printf '  %-32s \033[0;32mPASS\033[0m\n' "$name"; pass=$((pass+1))
  else
    printf '  %-32s \033[0;31mFAIL\033[0m\n' "$name"; sed 's/^/      /' /tmp/hc.$$; fail=$((fail+1))
  fi
done
rm -f /tmp/hc.$$
echo
ok "verify: $pass passed, $fail failed, $skipped skipped"
[[ $fail -eq 0 ]]
