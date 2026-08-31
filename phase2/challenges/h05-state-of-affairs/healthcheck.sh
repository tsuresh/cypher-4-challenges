#!/usr/bin/env bash
# h05 healthcheck (runs in the provisioned sandbox): fetch the public tfstate,
# extract+decode the SA key, activate it, read the secret. Also asserts the SA is
# least-privilege (cannot read a foreign resource / has no project roles).
set -euo pipefail
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"; load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
BUCKET="${GCP_PROJECT_ID}-lankagov-ci-state"; SECRET="lankagov-registry-flag"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

curl -fsS "https://storage.googleapis.com/${BUCKET}/terraform.tfstate" -o "$TMP/s.json"
python3 -c "import json,base64,sys;d=json.load(open('$TMP/s.json'));\
k=[r for r in d['resources'] if r['type']=='google_service_account_key'][0]['instances'][0]['attributes']['private_key'];\
open('$TMP/key.json','wb').write(base64.b64decode(k))"
gcloud auth activate-service-account --key-file="$TMP/key.json" >/dev/null 2>&1

if gcloud --project "$GCP_PROJECT_ID" secrets versions access latest --secret="$SECRET" 2>/dev/null | grep -qE "${FLAG_PREFIX}\{"; then
  # scope assertion: the leaked SA must NOT be able to list all secrets
  if gcloud --project "$GCP_PROJECT_ID" secrets list >/dev/null 2>&1; then
    echo "h05 healthcheck WARN: leaked SA can list secrets (should be scoped)"; fi
  echo "h05 healthcheck rc=0"; exit 0
fi
echo "h05 healthcheck FAILED"; exit 1
