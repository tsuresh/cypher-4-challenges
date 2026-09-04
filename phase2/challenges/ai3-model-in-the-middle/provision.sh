#!/usr/bin/env bash
# ai3 The Model in the Middle — shared instance: one container for every team (stateless
# mock-LLM, no per-team isolation needed). Runs directly on the platform VM, not whale.
# Applies the SECURITY.md §1 hardening pattern (mem/cpu/pids/read-only) even though this
# app has no RCE surface, for consistency with every other exploitable-service container.
# Expects CHAL_FLAG. Prints CONNECT=.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

NAME=cypher-p2-ai3
PORT=8022

step "ai3: (re)starting shared instance on :$PORT"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -e FLAG="$CHAL_FLAG" \
  --memory=256m --memory-swap=256m --pids-limit=128 --cpus=0.5 \
  --read-only --tmpfs /tmp:size=16m \
  -p "$PORT:8000" --restart unless-stopped cypher-p2/ai3:latest >/dev/null

ok "ai3: running as $NAME on :$PORT"
echo "CONNECT=http://$(vm_ip cypher-phase2 2>/dev/null || echo '<phase2-vm-ip>'):$PORT/"
