#!/usr/bin/env bash
# shared/lib/render.sh — render a challenge into a gitignored build dir with the
# real flag + connection info substituted in, then hand it to ctfcli.
#
# Challenge.yml files are committed with PLACEHOLDERS only, so no secret flag
# ever lands in git history:
#   __FLAG__     -> the real generated flag
#   __CONNECT__  -> connection info (URL, host:port, or bucket)
#
# Sourced after common.sh + flags.sh.

# _sed_escape <string> — escape a replacement string for sed (\, &, |, newline)
_sed_escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g' -e ':a;N;$!ba;s/\n/\\n/g'; }

# render_challenge <challenge_dir> <flag> <connect> -> echoes the rendered build dir
render_challenge() {
  local src="$1" flag="$2" connect="${3:-}"
  local cid; cid="$(basename "$src")"
  local dest; dest="$(state_dir)/build/$(basename "$(dirname "$src")")/$cid"
  rm -rf "$dest"; mkdir -p "$dest"
  cp -a "$src/." "$dest/"
  # Substitute placeholders in the rendered challenge.yml only. Replacement
  # strings are escaped so URLs/keys containing sed metacharacters are safe.
  if [[ -f "$dest/challenge.yml" ]]; then
    local f_esc c_esc; f_esc="$(_sed_escape "$flag")"; c_esc="$(_sed_escape "$connect")"
    sed -i \
      -e "s|__FLAG__|${f_esc}|g" \
      -e "s|__CONNECT__|${c_esc}|g" \
      "$dest/challenge.yml"
  fi
  register_flag "$cid" "$flag"
  printf '%s' "$dest"
}

# ctfcli_install <rendered_dir> — install/update a single challenge in CTFd
ctfcli_install() {
  local dir="$1"
  : "${CTFD_URL:?CTFD_URL not set}"; : "${CTFD_ADMIN_TOKEN:?CTFD_ADMIN_TOKEN not set}"
  ( cd "$REPO_ROOT"
    export CTFCLI_URL="$CTFD_URL" CTFCLI_ACCESS_TOKEN="$CTFD_ADMIN_TOKEN"
    if ! ctfcli challenge install "$dir" >/dev/null 2>&1; then
      ctfcli challenge sync "$dir" >/dev/null
    fi
  )
}

# render_and_sync <challenge_dir> <flag> <connect>
render_and_sync() {
  local built; built="$(render_challenge "$1" "$2" "${3:-}")"
  ctfcli_install "$built"
  ok "synced $(basename "$1")  ($3)"
}
