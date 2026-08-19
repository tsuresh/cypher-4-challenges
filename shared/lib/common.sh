#!/usr/bin/env bash
# shared/lib/common.sh — sourced by every script.
# Loads .env, sets strict mode, logging, and dependency checks.
# Usage: source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"

set -Eeuo pipefail

# --- Resolve repo root regardless of caller's CWD ---------------------------
if REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  # Fallback: two levels up from shared/lib
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
export REPO_ROOT

# --- Colours / logging ------------------------------------------------------
if [[ -t 1 ]]; then
  _C_RED='\033[0;31m'; _C_GRN='\033[0;32m'; _C_YLW='\033[0;33m'
  _C_BLU='\033[0;34m'; _C_DIM='\033[2m'; _C_RST='\033[0m'
else
  _C_RED=''; _C_GRN=''; _C_YLW=''; _C_BLU=''; _C_DIM=''; _C_RST=''
fi

log()   { printf '%b[*]%b %s\n' "$_C_BLU" "$_C_RST" "$*"; }
ok()    { printf '%b[+]%b %s\n' "$_C_GRN" "$_C_RST" "$*"; }
warn()  { printf '%b[!]%b %s\n' "$_C_YLW" "$_C_RST" "$*" >&2; }
err()   { printf '%b[x]%b %s\n' "$_C_RED" "$_C_RST" "$*" >&2; }
die()   { err "$*"; exit 1; }
step()  { printf '\n%b==>%b %s\n' "$_C_BLU" "$_C_RST" "$*"; }

# --- Load .env --------------------------------------------------------------
load_env() {
  local env_file="${1:-$REPO_ROOT/.env}"
  [[ -f "$env_file" ]] || die "Missing $env_file — copy .env.example to .env and fill it in."
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
  : "${GCP_PROJECT_ID:?GCP_PROJECT_ID not set in .env}"
  : "${GCP_REGION:?GCP_REGION not set in .env}"
  : "${GCP_ZONE:?GCP_ZONE not set in .env}"
  : "${FLAG_PREFIX:?FLAG_PREFIX not set in .env}"
}

# --- Dependency checks ------------------------------------------------------
require() {
  local missing=0 c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      err "Required command not found: $c"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || die "Install the missing tools and re-run."
}

# --- Confirmation prompt (skipped when ASSUME_YES=1) ------------------------
confirm() {
  local prompt="${1:-Proceed?}"
  [[ "${ASSUME_YES:-0}" == "1" ]] && return 0
  read -r -p "$prompt [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# --- State dir for generated flags / provisioning receipts ------------------
state_dir() {
  local d="$REPO_ROOT/.state"
  mkdir -p "$d"
  printf '%s' "$d"
}
