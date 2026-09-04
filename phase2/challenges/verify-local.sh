#!/usr/bin/env bash
# verify-local.sh — run every locally-verifiable Phase 2 challenge healthcheck and
# tally pass/fail. Cloud/GKE challenges (e01,m01,h05,h02,h03,i05) require the live
# sandbox and are listed as SKIP here (run their healthchecks in the sandbox, or
# i01/h01 with LIVE=1). Container-escape h16 build+privilege-verifies locally.
# ai1/ai2/ai3 (mock-LLM shared instances) build+solve locally like any other container.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; P=9300
declare -a LOCAL=(i03 i04 h12 m03 h10 h14 h15 e02 i02 h06 h08 i01 h01 h16 ai1 ai2 ai3)
declare -A DIR=(
  [i03]=i03-broadcast-blunder [i04]=i04-return-to-sender [h12]=h12-serendib-machine
  [m03]=m03-echo-chamber [h10]=h10-once-is-enough [h14]=h14-paper-trail
  [h15]=h15-quiet-on-the-wire [e02]=e02-client-side-story [i02]=i02-entity-crisis
  [h06]=h06-render-unto-ceylon [h08]=h08-polluted-pearls [i01]=i01-metadata-skim
  [h01]=h01-token-relay [h16]=h16-overboard-again
  [ai1]=ai1-serendib-support-bot [ai2]=ai2-jailbreak-concierge [ai3]=ai3-model-in-the-middle )

for id in "${LOCAL[@]}"; do
  P=$((P+1))
  out="$(CHAL_FLAG="CYPHER{verify_${id}_$(date +%s)}" PORT=$P \
         bash "$HERE/${DIR[$id]}/healthcheck.sh" 2>/dev/null || true)"
  if grep -q "rc=0" <<<"$out"; then printf '  PASS  %-4s %s\n' "$id" "${DIR[$id]}"; PASS=$((PASS+1))
  else printf '  FAIL  %-4s %s\n' "$id" "${DIR[$id]}"; FAIL=$((FAIL+1)); fi
done
echo "----------------------------------------"
echo "local verified: $PASS passed, $FAIL failed  (of ${#LOCAL[@]})"
echo "SKIP (need live GCP/GKE sandbox): e01 m01 h05 h02 h03 i05"
[ "$FAIL" -eq 0 ]
