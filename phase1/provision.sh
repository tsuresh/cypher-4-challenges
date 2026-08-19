#!/usr/bin/env bash
# phase1/provision.sh — bring up Phase 1 end to end on the phase-1 VM.
#
#   ./phase1/provision.sh
#
# Order (matches the build brief):
#   1. generate per-challenge flags (never committed)
#   2. bring up CTFd + container challenges (compose)
#   3. bootstrap CTFd over the API (admin, token, scoring, freeze)
#   4. provision GCP-native + kind + dind challenges via gcloud/kind/docker
#   5. render each challenge.yml with its flag + connection info and sync via ctfcli
#   6. print a summary + run healthchecks
#
# Re-runnable. Requires: docker, gcloud, gsutil, ctfcli, python3 (+requests), kind, kubectl, curl.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/flags.sh"
source "$REPO_ROOT/shared/lib/gcp.sh"
source "$REPO_ROOT/shared/lib/render.sh"
# Prefer a project venv (ctfcli/requests) if one exists.
[[ -d "$REPO_ROOT/.venv" ]] && PATH="$REPO_ROOT/.venv/bin:$PATH"
require docker gcloud gsutil ctf python3 curl   # ctfcli installs its CLI as `ctf`

CH="$REPO_ROOT/phase1/challenges"
export PHASE1_VM="${PHASE1_VM:-cypher-phase1}"
VM_IP="$(vm_ip "$PHASE1_VM" 2>/dev/null || echo localhost)"

gen_flag() { make_flag "$1_$(random_token 4)"; }
# capture "CONNECT=..." emitted by a challenge provision.sh
run_chal_provision() { CHAL_FLAG="$2" bash "$1/provision.sh" 2>&1 | tee /dev/stderr | sed -n 's/^CONNECT=//p' | tail -1; }

# --- 1. Flags --------------------------------------------------------------
step "Generating Phase 1 flags"
export FLAG_02="$(gen_flag ledger)"
export FLAG_03="$(gen_flag backup)"
export FLAG_05="$(gen_flag githappens)"
FLAG_00="CYPHER{welcome_to_cypher}"    # public warm-up
FLAG_01="$(gen_flag warehouse)"
FLAG_04="$(gen_flag metadata)"
FLAG_06="$(gen_flag signed)"
FLAG_07="$(gen_flag permissions)"
FLAG_08="$(gen_flag container)"
FLAG_09="$(gen_flag cluster)"
FLAG_10="$(gen_flag functionleak)"
FLAG_11="$(gen_flag escalation)"

# --- 2. CTFd + container challenges ----------------------------------------
# Ensure a stable CTFd session secret (required with >1 worker). Generate once
# and persist so re-runs don't invalidate live sessions.
if [[ -z "${CTFD_SECRET_KEY:-}" ]]; then
  _sk="$(state_dir)/ctfd_secret_key"
  [[ -f "$_sk" ]] || { random_token 32 > "$_sk"; chmod 600 "$_sk"; }
  export CTFD_SECRET_KEY="$(cat "$_sk")"
  log "Using CTFd SECRET_KEY from $_sk"
fi

step "Bringing up CTFd + container challenges (docker compose)"
( cd "$REPO_ROOT/phase1"
  docker compose --env-file "$REPO_ROOT/.env" up -d --build )

# --- 3. Bootstrap CTFd -----------------------------------------------------
step "Waiting for CTFd, then bootstrapping over the API"
source "$REPO_ROOT/shared/lib/healthcheck.sh"
http_status "http://localhost:8000/setup" 200 60 || http_status "http://localhost:8000/" 200 60

ADMIN_PASS="${CTFD_ADMIN_PASSWORD:-}"
[[ -z "$ADMIN_PASS" ]] && { ADMIN_PASS="$(random_token 12)"; warn "Generated CTFd admin password: $ADMIN_PASS  (save it!)"; }

export CTFD_URL="http://localhost:8000"
CTFD_ADMIN_TOKEN="$(python3 "$REPO_ROOT/shared/ctfd-base/bootstrap_ctfd.py" \
  --url "$CTFD_URL" \
  --admin-user "${CTFD_ADMIN_USER:-admin}" \
  --admin-email "${CTFD_ADMIN_EMAIL:-admin@example.lk}" \
  --admin-pass "$ADMIN_PASS" \
  --ctf-name "CYPHER 4.0 — Recruitment Trials" \
  --scoreboard public)"
export CTFD_ADMIN_TOKEN
[[ -n "$CTFD_ADMIN_TOKEN" ]] || die "Failed to obtain CTFd admin token"
ok "CTFd bootstrapped; admin token acquired"

# --- 4+5. Provision GCP/kind/dind challenges, then render+sync each ---------
step "Provisioning cloud/kind/container challenges and syncing to CTFd"

# No-infra
render_and_sync "$CH/00-practice-range"  "$FLAG_00" ""
render_and_sync "$CH/12-blue-team-brief" "n/a"      ""

# Container challenges already running via compose — connection = VM IP + port
render_and_sync "$CH/02-leaked-ledger"    "$FLAG_02" "http://${VM_IP}:8002/"
render_and_sync "$CH/03-forgotten-backup" "$FLAG_03" "http://${VM_IP}:8003/"
render_and_sync "$CH/05-git-happens"      "$FLAG_05" "http://${VM_IP}:8005/"

# GCP / kind / dind — each challenge's provision.sh creates resources & prints CONNECT
C01="$(run_chal_provision "$CH/01-open-warehouse"          "$FLAG_01")"; render_and_sync "$CH/01-open-warehouse"          "$FLAG_01" "$C01"
C04="$(run_chal_provision "$CH/04-metadata-mischief"       "$FLAG_04")"; render_and_sync "$CH/04-metadata-mischief"       "$FLAG_04" "$C04"
C06="$(run_chal_provision "$CH/06-signed-and-sealed"       "$FLAG_06")"; render_and_sync "$CH/06-signed-and-sealed"       "$FLAG_06" "$C06"
C07="$(run_chal_provision "$CH/07-too-many-permissions"    "$FLAG_07")"; render_and_sync "$CH/07-too-many-permissions"    "$FLAG_07" "$C07"
C08="$(run_chal_provision "$CH/08-careless-container"      "$FLAG_08")"; render_and_sync "$CH/08-careless-container"      "$FLAG_08" "$C08"
C09="$(run_chal_provision "$CH/09-peering-into-the-cluster" "$FLAG_09")"; render_and_sync "$CH/09-peering-into-the-cluster" "$FLAG_09" "$C09"
C10="$(run_chal_provision "$CH/10-function-leak"           "$FLAG_10")"; render_and_sync "$CH/10-function-leak"           "$FLAG_10" "$C10"
C11="$(run_chal_provision "$CH/11-the-escalation"          "$FLAG_11")"; render_and_sync "$CH/11-the-escalation"          "$FLAG_11" "$C11"

# --- 6. Summary ------------------------------------------------------------
step "Phase 1 provisioning complete"
cat <<EOF

  Scoreboard : https://ctfd.${BASE_DOMAIN}/scoreboard   (public)
  Admin (local): $CTFD_URL   user=${CTFD_ADMIN_USER:-admin}
  Flag registry: $(state_dir)/flags.csv   (gitignored)

Next:
  - Run the full solve verification:  ./phase1/verify.sh
  - Review briefs for the tie-break:  ./phase1/review-briefs.sh
EOF
