#!/usr/bin/env bash
# phase2/load-ctfd.sh — load the 20 finals challenges into an EXISTING CTFd via
# ctfcli, with correct flags, connection info, attachments, and state.
#   CTFD_URL and .state/ctfd_admin_token must be set/present.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/flags.sh"
source "$REPO_ROOT/shared/lib/render.sh"
[[ -d "$REPO_ROOT/.venv" ]] && PATH="$REPO_ROOT/.venv/bin:$PATH"

export CTFD_URL="${CTFD_URL:-https://cypher4.gdgsrilanka.org}"
export CTFD_ADMIN_TOKEN="$(cat "$(state_dir)/ctfd_admin_token")"
VM="${PHASE2_VM_IP:-34.14.164.225}"; P="$GCP_PROJECT_ID"
CH="$REPO_ROOT/phase2/challenges"

# Undeployed (dedicated-VM / GKE / nested-sandbox — quota-blocked) -> load HIDDEN.
HIDDEN=" i01 h01 h16 h03 i05 "

# short-id -> connection_info
declare -A CONN=(
  [e01]="gs://${P}-aw-surfcam   (public, listable: gsutil ls -r)"
  [m01]="gs://${P}-ck-recon     (denied anonymously; any authenticated Google account can read)"
  [h05]="gs://${P}-lankagov-ci-state/terraform.tfstate   (public)"
  [h02]="Activate the attached key; deploy a function as ruhunu-core@${P}.iam.gserviceaccount.com to read secret 'ruhunu-crownjewels'"
  [i01]="Instance is provisioned at the start of the round."
  [h01]="Instance is provisioned at the start of the round."
  [e02]="http://${VM}:8002/"
  [i02]="http://${VM}:8003/"
  [m03]="http://${VM}:8004/"
  [h06]="http://${VM}:8006/"
  [h08]="http://${VM}:8008/"
  [h10]="http://${VM}:8010/"
  [i04]="nc ${VM} 8014"
  [i03]="Download the attached capture.txt"
  [h12]="Download the attached binary"
  [h14]="Download the attached audit-logs.tar.gz"
  [h15]="Download the attached capture.pcap"
  [h16]="Instance is provisioned at the start of the round."
  [h03]="Cluster access is provisioned at the start of the round."
  [i05]="Cluster access is provisioned at the start of the round."
)

ok_n=0; fail_n=0
for dir in "$CH"/*/; do
  cid="$(basename "$dir")"; short="${cid%%-*}"
  [[ -f "$dir/challenge.yml" ]] || continue
  flag="$(lookup_flag "$short" 2>/dev/null || true)"; [[ -n "$flag" ]] || flag="$(lookup_flag "$cid" 2>/dev/null || true)"
  [[ -n "$flag" ]] || { warn "no flag for $cid — skipping"; fail_n=$((fail_n+1)); continue; }
  connect="${CONN[$short]:-Download the attached file}"
  built="$(render_challenge "$dir" "$flag" "$connect")"
  if [[ " $HIDDEN " == *" $short "* ]]; then
    sed -i 's/^state:[[:space:]].*/state: hidden/' "$built/challenge.yml"
  fi
  if ctfcli_install "$built" 2>/dev/null; then
    state="visible"; [[ " $HIDDEN " == *" $short "* ]] && state="HIDDEN"
    printf '  [+] %-26s %-8s %s\n' "$cid" "$state" "$connect"; ok_n=$((ok_n+1))
  else
    printf '  [x] %-26s FAILED\n' "$cid"; fail_n=$((fail_n+1))
  fi
done
echo "----------------------------------------"
echo "loaded: $ok_n  failed: $fail_n"
