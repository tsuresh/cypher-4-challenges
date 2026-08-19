#!/usr/bin/env bash
# phase1/provision-local.sh — populate a LOCAL CTFd with the laptop-runnable
# Phase 1 challenges. No GCP, no VM. Mirrors provision.sh but only for the
# challenges that work off-cloud, wiring their flags to local containers.
#
#   ./phase1/provision-local.sh          # bring up + load local challenges
#
# Loads:  00, 02, 03, 04*, 05, 08, 12   (*04 shows, but its metadata solve needs GCE)
# Skips:  01, 06, 07, 09, 10, 11         (need GCS/IAM/Secret Manager/kind — use the VM)
#
# Requires: docker, and a .venv with ctfcli + requests (see README "local testing").

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/flags.sh"
source "$REPO_ROOT/shared/lib/render.sh"

# Prefer the project venv's ctfcli/python if present.
[[ -d "$REPO_ROOT/.venv" ]] && PATH="$REPO_ROOT/.venv/bin:$PATH"
require docker ctfcli
PY="$(command -v python3)"; [[ -x "$REPO_ROOT/.venv/bin/python" ]] && PY="$REPO_ROOT/.venv/bin/python"

CH="$REPO_ROOT/phase1/challenges"
HOST_ADDR="${LOCAL_HOST:-localhost}"

# --- secret key (multi-worker requirement) ---------------------------------
if [[ -z "${CTFD_SECRET_KEY:-}" ]]; then
  _sk="$(state_dir)/ctfd_secret_key"
  [[ -f "$_sk" ]] || { random_token 32 > "$_sk"; chmod 600 "$_sk"; }
  export CTFD_SECRET_KEY="$(cat "$_sk")"
fi

# --- flags -----------------------------------------------------------------
step "Generating local flags"
export FLAG_02="$(make_flag "ledger_$(random_token 4)")"
export FLAG_03="$(make_flag "backup_$(random_token 4)")"
export FLAG_05="$(make_flag "githappens_$(random_token 4)")"
FLAG_00="CYPHER{welcome_to_cypher}"
FLAG_04="$(make_flag "metadata_$(random_token 4)")"
FLAG_08="$(make_flag "container_$(random_token 4)")"

# --- bring up CTFd core + container challenges (no proxy => no TLS) ---------
step "Bringing up CTFd + local container challenges"
( cd "$REPO_ROOT/phase1"
  docker compose --env-file "$REPO_ROOT/.env" up -d --build \
    ctfd db cache \
    c02-leaked-ledger c03-forgotten-backup c04-metadata-mischief \
    c05-git-happens c08-dind )

# --- wait for CTFd, bootstrap, get token -----------------------------------
step "Waiting for CTFd, then bootstrapping over the API"
source "$REPO_ROOT/shared/lib/healthcheck.sh"
http_status "http://localhost:8000/setup" 200 60 || http_status "http://localhost:8000/login" 200 60

export CTFD_URL="http://localhost:8000"
CTFD_ADMIN_TOKEN="$("$PY" "$REPO_ROOT/shared/ctfd-base/bootstrap_ctfd.py" \
  --url "$CTFD_URL" \
  --admin-user "${CTFD_ADMIN_USER:-admin}" \
  --admin-email "${CTFD_ADMIN_EMAIL:-admin@example.lk}" \
  --admin-pass "${CTFD_ADMIN_PASSWORD:?set CTFD_ADMIN_PASSWORD in .env for local}" \
  --ctf-name "CYPHER 4.0 (local)" --scoreboard public)"
export CTFD_ADMIN_TOKEN
[[ -n "$CTFD_ADMIN_TOKEN" ]] || die "Failed to get CTFd token (is the admin password correct?)"
ok "CTFd token acquired"

# ctfcli reads .ctf/config from CWD (render.sh cds to REPO_ROOT).
mkdir -p "$REPO_ROOT/.ctf"
cat > "$REPO_ROOT/.ctf/config" <<EOF
[config]
url = ${CTFD_URL}
access_token = ${CTFD_ADMIN_TOKEN}
EOF

# --- 08 inner flag container inside the DinD sandbox -----------------------
step "Starting 08 inner container in the DinD sandbox"
if DOCKER_HOST=tcp://${HOST_ADDR}:8008 docker info >/dev/null 2>&1; then
  DOCKER_HOST=tcp://${HOST_ADDR}:8008 docker rm -f ceylon-inventory >/dev/null 2>&1 || true
  DOCKER_HOST=tcp://${HOST_ADDR}:8008 docker run -d --name ceylon-inventory \
    -e FLAG="$FLAG_08" alpine:3.20 sleep infinity >/dev/null 2>&1 \
    && ok "08 inner container running" || warn "08 inner container failed"
else
  warn "08 DinD API not up yet; re-run to load 08, or skip it"
fi

# --- load challenges via ctfcli --------------------------------------------
step "Loading local challenges into CTFd via ctfcli"
render_and_sync "$CH/00-practice-range"     "$FLAG_00" ""
render_and_sync "$CH/02-leaked-ledger"      "$FLAG_02" "http://${HOST_ADDR}:8002/"
render_and_sync "$CH/03-forgotten-backup"   "$FLAG_03" "http://${HOST_ADDR}:8003/"
render_and_sync "$CH/04-metadata-mischief"  "$FLAG_04" "http://${HOST_ADDR}:8004/  (SSRF app runs; metadata solve needs a GCE VM)"
render_and_sync "$CH/05-git-happens"        "$FLAG_05" "http://${HOST_ADDR}:8005/"
render_and_sync "$CH/08-careless-container" "$FLAG_08" "tcp://${HOST_ADDR}:8008"
render_and_sync "$CH/12-blue-team-brief"    "n/a"      ""

step "Local provisioning complete"
cat <<EOF

  CTFd:        http://localhost:8000       (admin / \$CTFD_ADMIN_PASSWORD)
  Challenges:  http://localhost:8000/challenges
  Scoreboard:  http://localhost:8000/scoreboard

  Solvable locally: 00, 02, 03, 05, 08, 12   (04 visible; its flag needs GCE)
  Not loaded (need cloud/VM): 01, 06, 07, 09, 10, 11 — use ./phase1/provision.sh

  Flags for testing are in: $(state_dir)/flags.csv
  Tear down: cd phase1 && docker compose --env-file ../.env down
EOF
