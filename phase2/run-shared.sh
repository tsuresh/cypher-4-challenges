#!/usr/bin/env bash
# phase2/run-shared.sh — run the container challenges as SHARED single instances on
# the finals VM (cypher-phase2), each on a fixed port in the 8000-8099 range.
#
# Excluded (need dedicated scoped-SA VMs / a nested sandbox — see SECURITY.md):
#   i01, h01 (SSRF -> would steal this VM's metadata token)
#   h16      (privileged escape -> host root)
#
# Hardens the host first: block container egress to the GCE metadata server so a
# challenge RCE (h06/h08/i04) cannot exfiltrate this VM's SA token (SECURITY.md §2).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/flags.sh"

# id -> "hostport:internalport"
declare -A PORTS=(
  [e02-client-side-story]=8002:8000
  [i02-entity-crisis]=8003:8000
  [m03-echo-chamber]=8004:8000
  [h06-render-unto-ceylon]=8006:8000
  [h08-polluted-pearls]=8008:8000
  [h10-once-is-enough]=8010:8000
  [i04-return-to-sender]=8014:9104
)
declare -A IMGID=(
  [e02-client-side-story]=e02 [i02-entity-crisis]=i02 [m03-echo-chamber]=m03
  [h06-render-unto-ceylon]=h06 [h08-polluted-pearls]=h08 [h10-once-is-enough]=h10
  [i04-return-to-sender]=i04
)

step "Hardening: block container -> metadata HTTP (169.254.169.254:80), keep DNS"
# NOTE: on GCE 169.254.169.254 is ALSO the DNS resolver, so block only the metadata
# HTTP port (80) — a blanket DROP breaks DNS and every apt/pip in a build.
sudo iptables -D DOCKER-USER -d 169.254.169.254 -j DROP 2>/dev/null || true   # remove any old blanket rule
if ! sudo iptables -C DOCKER-USER -d 169.254.169.254 -p tcp --dport 80 -j DROP 2>/dev/null; then
  sudo iptables -I DOCKER-USER -d 169.254.169.254 -p tcp --dport 80 -j DROP \
    && ok "metadata HTTP blocked for containers (DNS preserved)"
else
  ok "metadata HTTP already blocked"
fi

step "Building images"
bash "$REPO_ROOT/phase2/build-images.sh" e02 i02 m03 h06 h08 h10 i04

step "Running shared instances"
for cid in "${!PORTS[@]}"; do
  hp="${PORTS[$cid]%%:*}"; ip="${PORTS[$cid]##*:}"; img="cypher-p2/${IMGID[$cid]}:latest"
  flag="$(lookup_flag "$cid" 2>/dev/null || true)"
  [[ -n "$flag" ]] || { flag="$(make_flag "${cid//-/_}_$(random_token 4)")"; register_flag "$cid" "$flag"; }
  docker rm -f "cypher-p2-${IMGID[$cid]}" >/dev/null 2>&1 || true
  docker run -d --name "cypher-p2-${IMGID[$cid]}" --restart unless-stopped \
    -e FLAG="$flag" -p "${hp}:${ip}" \
    --memory=256m --memory-swap=256m --pids-limit=128 --cpus=0.5 \
    "$img" >/dev/null
  ok "$cid -> :${hp}  (flag registered)"
done

VM_IP="$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo '<vm-ip>')"
step "Shared instances up. Connection base: http://${VM_IP}:<port>/"
for cid in "${!PORTS[@]}"; do printf '  %-26s http://%s:%s/\n' "$cid" "$VM_IP" "${PORTS[$cid]%%:*}"; done
