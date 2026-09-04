#!/usr/bin/env bash
# phase2/provision.sh — bring the finals set up end-to-end on cypher-phase2.
# Mirrors phase1/provision.sh, adapted for the flat phase2/challenges/ pool +
# ctfd-whale per-team instances.
#
#   ./phase2/provision.sh                 # platform + cloud/static challenges + CTFd load
#   PHASE2_GKE=1 ./phase2/provision.sh    # also provision the GKE challenges (needs a cluster + quota)
#
# Order:
#   1. flags (reuse .state/flags.csv if present; else generate)   — never committed
#   2. platform up: CTFd + ctfd-whale + frp + proxy (phase2/whale/)
#   3. bootstrap CTFd over the API (admin, token, PUBLIC board, FREEZE)
#   4. build per-team whale images
#   5. per-challenge provision.sh (cloud / GKE / static artifacts) + render+load challenge.yml
#   6. summary + whale reminder
#
# Requires: docker, gcloud, gsutil, ctf (ctfcli), python3(+requests), kubectl (for GKE).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/flags.sh"
source "$REPO_ROOT/shared/lib/gcp.sh"
source "$REPO_ROOT/shared/lib/render.sh"
[[ -d "$REPO_ROOT/.venv" ]] && PATH="$REPO_ROOT/.venv/bin:$PATH"
require docker ctf python3 curl

CH="$REPO_ROOT/phase2/challenges"
WHALE="$REPO_ROOT/phase2/whale"

# Challenge classes ---------------------------------------------------------
# cloud/static/gke challenges have their own provision.sh (run it, capture CONNECT).
# whale challenges are container images spawned per-team (no provision.sh; flag via whale).
GKE_IDS="h03-off-the-node i05-namespace-nomad"
# NOT ctfd-whale (that plumbing was never finished) — deployed as SHARED single instances
# on the platform VM instead, via phase2/run-shared.sh (already running; see its PORTS map).
# Kept per-challenge-unique flags where each has its own provision.sh (ai1/ai2/ai3); the
# run-shared.sh set (e02/i02/m03/h06/h08/h10/i04) has ONE flag shared by all teams — a known,
# accepted tradeoff for this event (see phase2/SECURITY.md's anti-cheat note).
SHARED_IDS="e02-client-side-story i02-entity-crisis m03-echo-chamber h06-render-unto-ceylon h08-polluted-pearls h10-once-is-enough i04-return-to-sender"
# NOT deployed anywhere yet — needs a nested throwaway sandbox per SECURITY.md §5 before it can
# run at all (a direct escape would land as root on the finals VM). Skipped, not loaded.
PENDING_IDS="h16-overboard-again"
CLOUD_IDS="e01-bucket-list m01-overshared h05-state-of-affairs h02-deploy-your-privilege h01-token-relay i01-metadata-skim"

# shared_connect <cid> -> connection_info for the already-running phase2/run-shared.sh
# instances (fixed host ports on cypher-phase2 — see that script's PORTS map).
shared_connect() {
  local ip; ip="$(vm_ip cypher-phase2 2>/dev/null || echo '<phase2-vm-ip>')"
  case "$1" in
    e02-client-side-story)    printf 'http://%s:8002/' "$ip" ;;
    i02-entity-crisis)        printf 'http://%s:8003/' "$ip" ;;
    m03-echo-chamber)         printf 'http://%s:8004/' "$ip" ;;
    h06-render-unto-ceylon)   printf 'http://%s:8006/' "$ip" ;;
    h08-polluted-pearls)      printf 'http://%s:8008/' "$ip" ;;
    h10-once-is-enough)       printf 'http://%s:8010/' "$ip" ;;
    i04-return-to-sender)     printf 'nc %s 8014' "$ip" ;;
    *)                        printf '' ;;
  esac
}

# When cloud resources are already provisioned (e.g. from a workstation with IAM
# admin), PHASE2_SKIP_CLOUD=1 loads the cloud challenges with their registered
# flags + a derived connection string instead of re-running gcloud on the VM.
cloud_connect() {  # cid -> connection_info string
  local p="$GCP_PROJECT_ID"
  case "$1" in
    e01-bucket-list)          printf 'gs://%s-aw-surfcam  (public, listable)' "$p" ;;
    m01-overshared)           printf 'gs://%s-ck-recon  (readable by any authenticated Google account)' "$p" ;;
    h05-state-of-affairs)     printf 'gs://%s-lankagov-ci-state/terraform.tfstate  (public)' "$p" ;;
    h02-deploy-your-privilege) printf 'Activate deployer-sa-key.json; deploy a function as ruhunu-core@%s.iam.gserviceaccount.com to read secret ruhunu-crownjewels' "$p" ;;
    i01-metadata-skim)        printf 'http://%s:8101/  (SSRF previewer on its dedicated scoped-SA VM)' "$(vm_ip cypher-i01 2>/dev/null || echo '<i01-vm>')" ;;
    h01-token-relay)          printf 'http://%s:8001/  (semi-blind SSRF on its dedicated scoped-SA VM)' "$(vm_ip cypher-h01 2>/dev/null || echo '<h01-vm>')" ;;
    *)                        printf '' ;;
  esac
}

flag_for() {  # reuse a registered flag, else make a fresh one
  local cid="$1" f; f="$(lookup_flag "$cid" 2>/dev/null || true)"
  [[ -n "$f" ]] || f="$(make_flag "${cid//-/_}_$(random_token 4)")"
  printf '%s' "$f"
}
capture_connect() { sed -n 's/^CONNECT=//p' | tail -1; }

# --- 1. platform + stable session secret -----------------------------------
if [[ -z "${CTFD_SECRET_KEY:-}" ]]; then
  _sk="$(state_dir)/ctfd_secret_key_p2"
  [[ -f "$_sk" ]] || { random_token 32 > "$_sk"; chmod 600 "$_sk"; }
  export CTFD_SECRET_KEY="$(cat "$_sk")"
fi

step "Bringing up the finals platform (CTFd + whale + frp)"
[[ -d "$REPO_ROOT/shared/ctfd-base/plugins/ctfd_whale" ]] \
  || warn "ctfd-whale plugin missing — clone it (see phase2/RUNBOOK.md) or whale challenges won't spawn."
( cd "$WHALE" && docker compose --env-file "$REPO_ROOT/.env" up -d )

# --- 2. bootstrap CTFd (public board + finals freeze) ----------------------
step "Waiting for CTFd, then bootstrapping"
source "$REPO_ROOT/shared/lib/healthcheck.sh"
http_status "http://localhost:8000/setup" 200 60 || http_status "http://localhost:8000/" 200 60

ADMIN_PASS="${CTFD_ADMIN_PASSWORD:-}"
[[ -z "$ADMIN_PASS" ]] && { ADMIN_PASS="$(random_token 12)"; warn "Generated CTFd admin password: $ADMIN_PASS (save it!)"; }
FREEZE_ARG=(); [[ -n "${PHASE2_FREEZE_EPOCH:-}" ]] && FREEZE_ARG=(--freeze-epoch "$PHASE2_FREEZE_EPOCH")

export CTFD_URL="http://localhost:8000"
CTFD_ADMIN_TOKEN="$(python3 "$REPO_ROOT/shared/ctfd-base/bootstrap_ctfd.py" \
  --url "$CTFD_URL" \
  --admin-user "${CTFD_ADMIN_USER:-admin}" \
  --admin-email "${CTFD_ADMIN_EMAIL:-admin@example.lk}" \
  --admin-pass "$ADMIN_PASS" \
  --ctf-name "CYPHER 4.0 — Operation Serendib Shield" \
  --scoreboard public "${FREEZE_ARG[@]}")"
export CTFD_ADMIN_TOKEN
[[ -n "$CTFD_ADMIN_TOKEN" ]] || die "Failed to obtain CTFd admin token"
ok "CTFd bootstrapped (public board; freeze=${PHASE2_FREEZE_EPOCH:-none})"

# --- 3. build per-team whale images ----------------------------------------
step "Building per-team challenge images"
bash "$REPO_ROOT/phase2/build-images.sh" || warn "some images failed to build"

# --- 4. per-challenge provision + render+load ------------------------------
step "Provisioning challenges and syncing to CTFd"
for dir in "$CH"/*/; do
  cid="$(basename "$dir")"
  [[ -f "$dir/challenge.yml" ]] || continue
  # skip GKE unless explicitly enabled
  if [[ " $GKE_IDS " == *" $cid "* && "${PHASE2_GKE:-0}" != "1" ]]; then
    warn "skipping $cid (GKE; set PHASE2_GKE=1 to enable)"; continue
  fi
  # skip challenges with no live infra yet (not loaded into CTFd until they are)
  if [[ " $PENDING_IDS " == *" $cid "* ]]; then
    warn "skipping $cid (no live infra yet — see SECURITY.md for what's needed)"; continue
  fi
  flag="$(flag_for "$cid")"; connect=""
  if [[ " $CLOUD_IDS " == *" $cid "* && "${PHASE2_SKIP_CLOUD:-0}" == "1" ]]; then
    connect="$(cloud_connect "$cid")"                       # already provisioned elsewhere
    ok "$cid: using pre-provisioned cloud resources (skip)"
  elif [[ -f "$dir/provision.sh" ]]; then
    connect="$(CHAL_FLAG="$flag" bash "$dir/provision.sh" 2>&1 | tee /dev/stderr | capture_connect || true)"
  elif [[ " $SHARED_IDS " == *" $cid "* ]]; then
    connect="$(shared_connect "$cid")"     # already running via phase2/run-shared.sh
    ok "$cid: using pre-running shared instance (skip)"
  fi
  render_and_sync "$dir" "$flag" "$connect"
done

# --- 5. summary ------------------------------------------------------------
step "Phase 2 provisioning complete"
VM_IP="$(vm_ip cypher-phase2 2>/dev/null || echo '<phase2-ip>')"
cat <<EOF

  Scoreboard : https://ctfd.${BASE_DOMAIN}/scoreboard   (public; freeze=${PHASE2_FREEZE_EPOCH:-none})
  Admin(local): $CTFD_URL   user=${CTFD_ADMIN_USER:-admin}
  Flag registry: $(state_dir)/flags.csv   (gitignored)
  Finals VM IP : $VM_IP

Next:
  1. h16 is NOT loaded (no live infra — needs a nested sandbox, SECURITY.md §5). Decide:
     drop it from this event, or stand up the nested sandbox before go-live.
  2. Verify solve paths:  ./phase2/verify.sh   and  ./phase2/challenges/verify-local.sh
  3. Firewall is currently 0.0.0.0/0 on the participant-facing rules — restrict to the
     venue CIDR before go-live if that's still wanted (phase2/SECURITY.md §7).
EOF
