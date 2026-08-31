#!/usr/bin/env bash
# h16 healthcheck. Builds the vulnerable image and verifies the container starts
# privileged with CAP_SYS_ADMIN (the misconfig). The full release_agent escape only
# fires on a cgroup-v1 host; where the host is cgroup-v2 (as most modern hosts are),
# this build-verifies and reports that the escape requires the cgroup-v1 sandbox.
#
# The finals sandbox for this challenge is a nested throwaway (rootless-DinD /
# gVisor / microVM) providing a cgroup-v1 "host" that holds /flag, so a breakout
# cannot reach the finals VM or the GCP project.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{cgroup_release_agent_escape}'
CID=""
trap '[ -n "$CID" ] && docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

docker build -q -t cypher-h16 "$HERE" >/dev/null
CID="$(docker run -d --privileged cypher-h16)"

# assert the container really has the dangerous capability + can mount (the misconfig)
CAPS="$(docker exec "$CID" sh -c 'grep CapEff /proc/self/status | awk "{print \$2}"')"
echo "CapEff=$CAPS"
if docker exec "$CID" sh -c 'mkdir -p /tmp/cg && mount -t tmpfs none /tmp/cg' >/dev/null 2>&1; then
  echo "privileged mount: OK (container can mount — escape primitive present)"
else
  echo "h16 healthcheck FAILED: container cannot mount (not privileged?)"; exit 1
fi

HOSTCG="$(stat -fc %T /sys/fs/cgroup 2>/dev/null || echo unknown)"
if [ "$HOSTCG" = "cgroup2fs" ]; then
  echo "host is cgroup-v2 -> release_agent escape not applicable here."
  echo "h16 healthcheck rc=0 (build+privilege verified; escape needs the cgroup-v1 sandbox)"
  exit 0
fi

# cgroup-v1 host: run the real escape against a flag placed on the host
echo "$FLAG" | sudo tee /flag >/dev/null 2>&1 || echo "$FLAG" > /flag
OUT="$(docker exec "$CID" /opt/exploit.sh 2>/dev/null || true)"
echo "escape output: $OUT"
case "$OUT" in *"$FLAG"*) echo "h16 healthcheck rc=0 (live escape)"; exit 0 ;; esac
echo "h16 healthcheck FAILED (escape did not recover flag)"; exit 1
