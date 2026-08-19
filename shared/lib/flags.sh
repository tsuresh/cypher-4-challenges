#!/usr/bin/env bash
# shared/lib/flags.sh — deterministic-yet-secret flag generation & registry.
# Sourced after common.sh.
#
# Flags follow ${FLAG_PREFIX}{...}. For per-team-unique (shared challenge) flags
# we derive from a per-event secret salt so the same challenge yields a stable
# but non-guessable flag. Flags are written to .state/flags.csv for the solve
# verifier and for ctfcli sync — never committed (see .gitignore).

# make_flag <inner>  ->  CYPHER{inner}
make_flag() {
  printf '%s{%s}' "${FLAG_PREFIX}" "$1"
}

# random_token <bytes>  -> url-safe hex token
random_token() {
  local bytes="${1:-8}"
  head -c "$bytes" /dev/urandom | od -An -tx1 | tr -d ' \n'
}

# event_salt — one secret per event, generated once, stored in .state/salt
event_salt() {
  local f; f="$(state_dir)/salt"
  if [[ ! -f "$f" ]]; then
    random_token 16 > "$f"
    chmod 600 "$f"
  fi
  cat "$f"
}

# unique_flag <challenge_id> <team_id>  — stable per (challenge,team) hash flag
# Used for "shared, unique flag" challenges (S1/S3/S6) so each team's copy
# resolves to a distinct value derived from the event salt.
unique_flag() {
  local cid="$1" team="$2" salt digest
  salt="$(event_salt)"
  digest="$(printf '%s:%s:%s' "$salt" "$cid" "$team" | sha256sum | cut -c1-16)"
  make_flag "${cid}_${digest}"
}

# register_flag <challenge_id> <flag>  — append to the flag registry
register_flag() {
  local cid="$1" flag="$2" reg
  reg="$(state_dir)/flags.csv"
  [[ -f "$reg" ]] || echo "challenge_id,flag" > "$reg"
  # de-dup: drop any prior line for this challenge id
  if [[ -f "$reg" ]]; then
    grep -v "^${cid}," "$reg" > "$reg.tmp" 2>/dev/null || true
    mv "$reg.tmp" "$reg"
  fi
  printf '%s,%s\n' "$cid" "$flag" >> "$reg"
  chmod 600 "$reg"
}

# lookup_flag <challenge_id>
lookup_flag() {
  local cid="$1" reg
  reg="$(state_dir)/flags.csv"
  [[ -f "$reg" ]] || return 1
  awk -F, -v c="$cid" '$1==c {print $2; found=1} END{exit !found}' "$reg"
}
