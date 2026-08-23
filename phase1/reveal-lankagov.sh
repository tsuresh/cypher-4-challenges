#!/usr/bin/env bash
# phase1/reveal-lankagov.sh — reveal / hide the LankaGov e-Services tie-break
# series (challenges 13 stages 1-3) as one atomic action.
#
#   ./phase1/reveal-lankagov.sh status     # show current state of the 3 cards
#   ./phase1/reveal-lankagov.sh show       # make all 3 visible (run at go-time)
#   ./phase1/reveal-lankagov.sh hide       # hide all 3 again
#
# Reveal is just flipping state -> visible; the CTFd requirements chain still
# forces stage order (players first see only "Front Door"; Records Room and The
# Vault stay locked until the prior stage is solved).
#
# Reads CTFd URL from .env (CTFD_PUBLIC_URL, else ctfd.$BASE_DOMAIN) and the
# admin token from .state/ctfd_admin_token. No secrets live in this file.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env

ACTION="${1:-status}"
CATEGORY="LankaGov e-Services"
URL="${CTFD_PUBLIC_URL:-https://ctfd.${BASE_DOMAIN}}"
TOKEN_FILE="$(state_dir)/ctfd_admin_token"
[[ -f "$TOKEN_FILE" ]] || die "admin token not found at $TOKEN_FILE"
TOKEN="$(cat "$TOKEN_FILE")"
PY="$(command -v python3)"; [[ -x "$REPO_ROOT/.venv/bin/python" ]] && PY="$REPO_ROOT/.venv/bin/python"

api() { curl -4 -fsS -H "Authorization: Token $TOKEN" -H 'Content-Type: application/json' "$@"; }

# Resolve the 3 card ids for this category (by name, so ids don't have to be
# hardcoded). The list view omits per-item `state`, so fetch each card's detail
# endpoint — only 3 calls — to report state accurately.
ids_and_states() {
  local ids
  ids="$(api "$URL/api/v1/challenges?view=admin" | "$PY" -c "
import json,sys
cat=sys.argv[1]
print(' '.join(str(c['id']) for c in json.load(sys.stdin)['data'] if c.get('category')==cat))
" "$CATEGORY")"
  local id
  for id in $ids; do
    api "$URL/api/v1/challenges/$id" | "$PY" -c "
import json,sys
c=json.load(sys.stdin)['data']
print(c['id'], c.get('state','?'), c['name'])
"
  done
}

set_state() {
  local target="$1" n=0
  while read -r id state name; do
    [[ -z "$id" ]] && continue
    if [[ "$state" == "$target" ]]; then
      ok "already $target: $name"
    else
      api -X PATCH -d "{\"state\":\"$target\"}" "$URL/api/v1/challenges/$id" >/dev/null \
        && ok "$target: $name" || err "failed: $name"
    fi
    n=$((n+1))
  done < <(ids_and_states)
  [[ $n -eq 3 ]] || warn "expected 3 LankaGov cards, acted on $n — check CTFd"
}

case "$ACTION" in
  status)
    step "LankaGov series — current state"
    ids_and_states | while read -r id state name; do printf '  [%s] %s (id=%s)\n' "$state" "$name" "$id"; done
    ;;
  show)
    step "Revealing LankaGov series"
    set_state visible
    log "Players will now see 'Front Door'; the later stages stay locked until solved."
    ;;
  hide)
    step "Hiding LankaGov series"
    set_state hidden
    ;;
  *) die "usage: $0 status|show|hide" ;;
esac
