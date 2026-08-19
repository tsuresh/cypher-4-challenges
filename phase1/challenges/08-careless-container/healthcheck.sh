#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
require docker curl
DIND_API="${1:-tcp://localhost:8008}"
HTTP_API="${DIND_API/tcp:\/\//http://}"
# API reachable and inner container present with a flag in its env.
DOCKER_HOST="$DIND_API" docker ps >/dev/null 2>&1 || { echo "08 FAIL: API unreachable"; exit 1; }
env_json="$(curl -fsS --max-time 5 "$HTTP_API/containers/ceylon-inventory/json" 2>/dev/null || true)"
if grep -qE "FLAG=CYPHER\{[^}]+\}" <<<"$env_json"; then
  echo "08 OK: inventory container exposes flag via env"
else
  echo "08 FAIL: inner container/flag not found"; exit 1
fi
