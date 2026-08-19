#!/usr/bin/env bash
# Run ON the VM (needs kubectl context kind-cypher09).
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
require kubectl curl
# Secret exists with a flag value.
val="$(kubectl --context kind-cypher09 -n aperide get secret driver-config \
  -o jsonpath='{.data.flag}' 2>/dev/null | base64 -d 2>/dev/null || true)"
if grep -qE "${FLAG_PREFIX}\{[^}]+\}" <<<"$val"; then
  ok "09: flag secret present in cluster"
else
  err "09 FAIL: flag secret missing — run setup-kind.sh"; exit 1
fi
# Dashboard port answers.
code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://localhost:8009/" || echo 000)"
[[ "$code" =~ ^(200|401|403)$ ]] && ok "09: dashboard responding on 8009 ($code)" || { err "09 FAIL: dashboard not on 8009"; exit 1; }
