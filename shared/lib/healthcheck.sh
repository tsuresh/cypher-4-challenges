#!/usr/bin/env bash
# shared/lib/healthcheck.sh — reusable checks for provisioning & CI dry-runs.
# Sourced after common.sh.

# http_contains <url> <needle> [max_tries] — poll until body contains needle
http_contains() {
  local url="$1" needle="$2" tries="${3:-30}" i body
  for ((i=1; i<=tries; i++)); do
    if body="$(curl -fsS --max-time 5 "$url" 2>/dev/null)"; then
      if grep -qF -- "$needle" <<<"$body"; then
        ok "healthcheck: $url contains expected marker"
        return 0
      fi
    fi
    sleep 2
  done
  err "healthcheck FAILED: $url did not contain '$needle' after $tries tries"
  return 1
}

# http_status <url> <expected_code> [max_tries]
http_status() {
  local url="$1" want="$2" tries="${3:-30}" i code
  for ((i=1; i<=tries; i++)); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || echo 000)"
    if [[ "$code" == "$want" ]]; then
      ok "healthcheck: $url -> HTTP $code"
      return 0
    fi
    sleep 2
  done
  err "healthcheck FAILED: $url returned '$code', wanted '$want'"
  return 1
}

# tcp_open <host> <port> [max_tries]
tcp_open() {
  local host="$1" port="$2" tries="${3:-30}" i
  for ((i=1; i<=tries; i++)); do
    if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
      exec 3>&- 3<&- 2>/dev/null || true
      ok "healthcheck: ${host}:${port} open"
      return 0
    fi
    sleep 2
  done
  err "healthcheck FAILED: ${host}:${port} not reachable"
  return 1
}

# flag_present <url> — the response body must carry a well-formed flag
flag_present() {
  local url="$1" body
  body="$(curl -fsS --max-time 5 "$url" 2>/dev/null)" || { err "no response from $url"; return 1; }
  if grep -qE "${FLAG_PREFIX}\{[^}]+\}" <<<"$body"; then
    ok "healthcheck: flag pattern present at $url"
    return 0
  fi
  err "healthcheck FAILED: no flag pattern at $url"
  return 1
}
