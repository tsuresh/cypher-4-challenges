#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
require docker
DIND_API="${DIND_API:-tcp://localhost:8008}"
DOCKER_HOST="$DIND_API" docker rm -f ceylon-inventory >/dev/null 2>&1 || true
echo "08 inner container removed"
