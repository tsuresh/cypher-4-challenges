#!/usr/bin/env bash
# phase2/build-images.sh — build & tag the per-team challenge images that
# ctfd-whale spawns on demand. Run on the finals VM before provisioning.
#
#   ./phase2/build-images.sh            # builds all
#   ./phase2/build-images.sh e02 h06    # builds a subset
#
# Images are tagged cypher-p2/<id>:latest and referenced by that name in the
# ctfd-whale challenge config (see phase2/whale/WHALE.md).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CH="$HERE/challenges"

# id -> challenge dir (only the container-backed challenges)
declare -A IMG=(
  [e02]=e02-client-side-story
  [i02]=i02-entity-crisis
  [i04]=i04-return-to-sender
  [m03]=m03-echo-chamber
  [h06]=h06-render-unto-ceylon
  [h08]=h08-polluted-pearls
  [h10]=h10-once-is-enough
  [h16]=h16-overboard-again
  # i01/h01 are deployed on DEDICATED scoped-SA VMs, not whale — see WHALE.md/SECURITY.md,
  # but their images are built here too for that deploy:
  [i01]=i01-metadata-skim
  [h01]=h01-token-relay
)

ids=("$@"); [ ${#ids[@]} -eq 0 ] && ids=("${!IMG[@]}")
for id in "${ids[@]}"; do
  dir="${IMG[$id]:-}"
  [ -n "$dir" ] || { echo "unknown image id: $id" >&2; continue; }
  echo ">> building cypher-p2/$id  (challenges/$dir)"
  docker build -q -t "cypher-p2/$id:latest" "$CH/$dir" >/dev/null
  echo "   ok: cypher-p2/$id:latest"
done
echo "done. Images:"; docker images --format '  {{.Repository}}:{{.Tag}} ({{.Size}})' | grep '^  cypher-p2/' || true
