#!/usr/bin/env bash
# h05 State of Affairs — a public CI bucket holding a terraform.tfstate that leaks
# a base64 service-account key (and a decoy DB password). The SA is least-privilege:
# only secretAccessor on the one flag secret. Expects CHAL_FLAG. Prints CONNECT=.
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

SECRET="lankagov-registry-flag"
SA_ID="lankagov-ci"
BUCKET="${GCP_PROJECT_ID}-lankagov-ci-state"

step "h05: secret + least-privilege SA"
ensure_secret "$SECRET" "$CHAL_FLAG"
SA_EMAIL="$(ensure_sa "$SA_ID" "LankaGov CI (scoped)")"
grant_secret_role "$SECRET" "$SA_EMAIL" roles/secretmanager.secretAccessor

step "h05: exporting a key and embedding it in terraform state"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
make_sa_key "$SA_EMAIL" "$TMP/key.json"
KEY_B64="$(base64 -w0 "$TMP/key.json")"

cat > "$TMP/terraform.tfstate" <<JSON
{
  "version": 4,
  "terraform_version": "1.7.5",
  "serial": 12,
  "lineage": "$(random_token 8)-lankagov",
  "resources": [
    {
      "mode": "managed", "type": "google_sql_user", "name": "app",
      "instances": [ { "attributes": { "name": "eservices", "password": "Pg!$(random_token 4)DecoyDB" } } ]
    },
    {
      "mode": "managed", "type": "google_service_account_key", "name": "ci_deploy",
      "instances": [ { "attributes": {
        "name": "projects/${GCP_PROJECT_ID}/serviceAccounts/${SA_EMAIL}/keys/ci",
        "service_account_id": "${SA_EMAIL}",
        "private_key": "${KEY_B64}"
      } } ]
    }
  ]
}
JSON

step "h05: publishing state to a public CI bucket"
URI="$(ensure_bucket "$BUCKET" public)"
GS cp "$TMP/terraform.tfstate" "$URI/terraform.tfstate" >/dev/null

ok "h05: provisioned. Secret=$SECRET SA=$SA_EMAIL state=$URI/terraform.tfstate"
echo "CONNECT=${URI}/terraform.tfstate  (public; leaks a base64 SA key -> secret '${SECRET}')"
