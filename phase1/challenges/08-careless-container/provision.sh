#!/usr/bin/env bash
# 08 Careless Container — start the flag-bearing inner container INSIDE the DinD
# sandbox (service c08-dind, Docker API exposed on host:8008). Escaping this
# challenge lands in the throwaway DinD, never the host.
#
# Expects CHAL_FLAG. Prints "CONNECT=tcp://<ip>:8008" on the last line.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
require docker
: "${CHAL_FLAG:?CHAL_FLAG required}"

DIND_API="${DIND_API:-tcp://localhost:8008}"

step "08: waiting for the exposed Docker API at $DIND_API"
for i in $(seq 1 30); do
  if DOCKER_HOST="$DIND_API" docker info >/dev/null 2>&1; then break; fi
  sleep 2
done
DOCKER_HOST="$DIND_API" docker info >/dev/null 2>&1 || die "DinD Docker API not reachable at $DIND_API"

step "08: launching inner inventory container with the flag in its environment"
DOCKER_HOST="$DIND_API" docker rm -f ceylon-inventory >/dev/null 2>&1 || true
# --restart unless-stopped: without it a host reboot leaves this container in
# Exited state. The DinD daemon and port 8008 come back, so the challenge LOOKS
# healthy, but `docker ps` (the intended solve) lists nothing.
DOCKER_HOST="$DIND_API" docker run -d --name ceylon-inventory \
  --restart unless-stopped \
  -e SERVICE=inventory-sync \
  -e FLAG="${CHAL_FLAG}" \
  alpine:3.20 sleep infinity >/dev/null
ok "08 inner container 'ceylon-inventory' running (flag in env FLAG)"

IP="$(vm_ip "${PHASE1_VM:-cypher-phase1}" 2>/dev/null || echo '<vm-ip>')"
echo "CONNECT=tcp://${IP}:8008"
