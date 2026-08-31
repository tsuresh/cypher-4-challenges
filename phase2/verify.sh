#!/usr/bin/env bash
# phase2/verify.sh — run the live-verifiable challenge healthchecks (cloud + static).
# Whale (per-team container) challenges are verified through the CTFd UI / locally
# with phase2/challenges/verify-local.sh; GKE ones need the cluster (LIVE mode).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
CH="$REPO_ROOT/phase2/challenges"
ACCT="$(gcloud config get-value account 2>/dev/null || true)"
PASS=0; FAIL=0

# cloud + static challenges whose healthcheck runs against live resources here
LIVE="e01-bucket-list m01-overshared h05-state-of-affairs i03-broadcast-blunder \
      h12-serendib-machine h14-paper-trail h15-quiet-on-the-wire"

for cid in $LIVE; do
  [[ -f "$CH/$cid/healthcheck.sh" ]] || continue
  step "verify $cid"
  if bash "$CH/$cid/healthcheck.sh" 2>&1 | tail -3 | grep -q 'rc=0'; then
    ok "$cid PASS"; PASS=$((PASS+1))
  else
    err "$cid FAIL"; FAIL=$((FAIL+1))
  fi
  [[ -n "$ACCT" ]] && gcloud config set account "$ACCT" >/dev/null 2>&1   # restore after any SA activation
done

echo "----------------------------------------"
echo "phase2 live verify: $PASS passed, $FAIL failed"
echo "i01/h01: LIVE=1 TARGET=http://<vm>:port ...  (dedicated SSRF VM)"
echo "h02: deploy-a-function healthcheck (billable) — run manually if desired"
echo "h03/i05: LIVE on the GKE cluster; whale challenges: phase2/challenges/verify-local.sh"
[[ "$FAIL" -eq 0 ]]
