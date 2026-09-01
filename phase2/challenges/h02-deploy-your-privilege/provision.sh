#!/usr/bin/env bash
# h02 Deploy Your Privilege — a deployer SA whose custom role bundles
# cloudfunctions.functions.create with actAs (serviceAccountUser) over a privileged
# runtime SA that can read the flag secret. No direct secret read; the escalation is
# to deploy a function that RUNS AS the runtime SA. Expects CHAL_FLAG. Prints CONNECT=.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SECRET="ruhunu-crownjewels"
CORE_SA="ruhunu-core"
DEP_SA="ruhunu-deployer"
ROLE_ID="ruhunuDeployer"
KEY_OUT="$HERE/deployer-sa-key.json"

step "h02: enabling APIs"
ensure_apis cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com \
            artifactregistry.googleapis.com secretmanager.googleapis.com

step "h02: secret + privileged runtime SA (secretAccessor on the one secret)"
ensure_secret "$SECRET" "$CHAL_FLAG"
CORE_EMAIL="$(ensure_sa "$CORE_SA" "Ruhunu Core Runtime")"
grant_secret_role "$SECRET" "$CORE_EMAIL" roles/secretmanager.secretAccessor

step "h02: deployer SA + custom role (functions.create — but NOT secretAccessor)"
DEP_EMAIL="$(ensure_sa "$DEP_SA" "Ruhunu Deployer")"
if ! GC iam roles describe "$ROLE_ID" >/dev/null 2>&1; then
  GC iam roles create "$ROLE_ID" \
    --title "Ruhunu Deployer" \
    --description "Ship functions (innocuous-looking)" \
    --permissions "cloudfunctions.functions.create,cloudfunctions.functions.get,cloudfunctions.functions.list,cloudfunctions.functions.sourceCodeSet,cloudfunctions.functions.call,cloudfunctions.operations.get,run.services.create,run.services.get,run.services.getIamPolicy,run.services.setIamPolicy,cloudbuild.builds.get,artifactregistry.repositories.get" \
    --stage GA --quiet >/dev/null
  ok "Created custom role $ROLE_ID"
fi
grant_project_role "$DEP_EMAIL" "projects/${GCP_PROJECT_ID}/roles/${ROLE_ID}"

# The lethal half: actAs over the runtime SA (resource-scoped serviceAccountUser).
grant_sa_impersonation "$CORE_EMAIL" "$DEP_EMAIL" roles/iam.serviceAccountUser

# The deployer ALSO needs enough to actually deploy a gen2 function (build/run/
# registry/storage) plus actAs on the Cloud Build SA. Deliberately NO secretAccessor,
# so the only path to the secret remains "deploy a workload that runs AS ruhunu-core".
# Without these the challenge is unsolvable (deploy fails with 403).
step "h02: granting deploy permissions (no secret access)"
for role in roles/cloudfunctions.developer roles/run.developer \
            roles/cloudbuild.builds.editor roles/artifactregistry.writer roles/storage.admin; do
  grant_project_role "$DEP_EMAIL" "$role"
done
PNUM="$(GC projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)')"
BUILD_SA="${PNUM}-compute@developer.gserviceaccount.com"
grant_sa_impersonation "$BUILD_SA" "$DEP_EMAIL" roles/iam.serviceAccountUser   # actAs the build SA
grant_project_role "$BUILD_SA" roles/cloudbuild.builds.builder                 # let the build run

step "h02: exporting deployer key (challenge attachment)"
[[ -f "$KEY_OUT" ]] && rm -f "$KEY_OUT"
make_sa_key "$DEP_EMAIL" "$KEY_OUT"

ok "h02: provisioned. Deployer can deploy AS $CORE_EMAIL which reads secret '$SECRET'"
echo "CONNECT=Activate deployer-sa-key.json; deploy a function --service-account=${CORE_EMAIL} that reads secret '${SECRET}'"
