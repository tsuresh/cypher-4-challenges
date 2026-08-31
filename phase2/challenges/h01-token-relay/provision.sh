#!/usr/bin/env bash
# h01 Token Relay — build the two-hop impersonation chain:
#   webhook-runner (VM SA, stolen via SSRF)
#     --tokenCreator--> relay
#       --tokenCreator--> vault-reader (secretAccessor on the flag secret)
# Each hop is least-privilege; no identity has project-wide access.
# Expects CHAL_FLAG. Prints CONNECT= (VM:port wired at compose time).
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
: "${CHAL_FLAG:?CHAL_FLAG required}"

SECRET="ape-ride-crownjewels"
RUNNER="webhook-runner"; RELAY="relay"; VAULT="vault-reader"

step "h01: secret + chain of least-privilege SAs"
ensure_apis iamcredentials.googleapis.com secretmanager.googleapis.com
ensure_secret "$SECRET" "$CHAL_FLAG"

RUNNER_EMAIL="$(ensure_sa "$RUNNER" "Ape Ride Webhook Runner (VM SA)")"
RELAY_EMAIL="$(ensure_sa  "$RELAY"  "Ape Ride Relay")"
VAULT_EMAIL="$(ensure_sa  "$VAULT"  "Ape Ride Vault Reader")"

# vault-reader is the only one that can read the secret
grant_secret_role "$SECRET" "$VAULT_EMAIL" roles/secretmanager.secretAccessor
# hop 2: relay can impersonate vault-reader
grant_sa_impersonation "$VAULT_EMAIL" "$RELAY_EMAIL"  roles/iam.serviceAccountTokenCreator
# hop 1: webhook-runner can impersonate relay
grant_sa_impersonation "$RELAY_EMAIL" "$RUNNER_EMAIL" roles/iam.serviceAccountTokenCreator

ok "h01: provisioned. VM must run the SSRF app as ${RUNNER_EMAIL}."
echo "CONNECT=http://<vm-ip>:8001/   (semi-blind SSRF; chain ${RUNNER} -> ${RELAY} -> ${VAULT} -> secret '${SECRET}')"
