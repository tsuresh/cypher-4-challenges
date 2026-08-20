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

# _yaml_dq <string> — render as a YAML double-quoted scalar.
# Needed because a PLAIN yaml scalar may not contain ": ", " #", or start with
# a flow indicator — e.g. challenge 07's connection_info ("Activate the attached
# key: gcloud auth ...") parses as a nested mapping and ctfcli refuses the file.
_yaml_dq() { printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"; }

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
    local f_esc c_esc fq cq
    f_esc="$(_sed_escape "$flag")"; c_esc="$(_sed_escape "$connect")"
    fq="$(_sed_escape "$(_yaml_dq "$flag")")"
    cq="$(_sed_escape "$(_yaml_dq "$connect")")"
    # Order matters: quote the real YAML VALUE positions first, then substitute
    # any remaining placeholders raw — those live inside `description: |` block
    # scalars, which are literal text and must not gain quotes.
    sed -i \
      -e "s|^connection_info:[[:space:]]*__CONNECT__[[:space:]]*$|connection_info: ${cq}|" \
      -e "s|^\([[:space:]]*\)-[[:space:]]*__FLAG__[[:space:]]*$|\1- ${fq}|" \
      -e "s|__FLAG__|${f_esc}|g" \
      -e "s|__CONNECT__|${c_esc}|g" \
      "$dest/challenge.yml"
  fi
  register_flag "$cid" "$flag"
  printf '%s' "$dest"
}

# ctfcli_install <rendered_dir> — install/update a single challenge in CTFd.
# NOTE: the ctfcli command-line tool is `ctf`. It reads .ctf/config from the CWD,
# which we (re)write here so both provision.sh and provision-local.sh work.
ctfcli_install() {
  local dir="$1"
  : "${CTFD_URL:?CTFD_URL not set}"; : "${CTFD_ADMIN_TOKEN:?CTFD_ADMIN_TOKEN not set}"
  mkdir -p "$REPO_ROOT/.ctf"
  cat > "$REPO_ROOT/.ctf/config" <<EOF
[config]
url = ${CTFD_URL}
access_token = ${CTFD_ADMIN_TOKEN}

[challenges]
EOF
  ( cd "$REPO_ROOT"
    if ! ctf challenge install "$dir" >/dev/null 2>&1; then
      ctf challenge sync "$dir" >/dev/null
    fi
  )
}

# render_and_sync <challenge_dir> <flag> <connect>
render_and_sync() {
  local built; built="$(render_challenge "$1" "$2" "${3:-}")"
  ctfcli_install "$built"
  ok "synced $(basename "$1")  ($3)"
}
