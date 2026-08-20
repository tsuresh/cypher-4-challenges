#!/usr/bin/env bash
# shared/lib/gcp.sh — idempotent gcloud helpers.
# Sourced after common.sh. Every helper is safe to run repeatedly.

# All wrappers pin --project so a mis-set gcloud default can never touch
# another project. This is the single most important safety property.
GC() { gcloud --project "$GCP_PROJECT_ID" "$@"; }
GS() { gsutil "$@"; }

# _iam_retry <description> <cmd...> — retry through IAM eventual consistency.
# A just-created service account is not immediately resolvable by the other IAM
# APIs: bindings that reference it fail with "does not exist" for a few seconds
# after creation. Retries the command rather than failing the whole run.
_iam_retry() {
  local desc="$1"; shift
  local n=0 out
  until out="$("$@" 2>&1)"; do
    n=$((n + 1))
    if [[ $n -ge 6 ]]; then
      printf '%s\n' "$out" >&2
      die "$desc: failed after $n attempts"
    fi
    warn "$desc: not settled yet (attempt $n/6), retrying in 5s"
    sleep 5
  done
  [[ -n "$out" ]] && printf '%s\n' "$out" >&2
  return 0
}

# ensure_apis <api...> — enable one or more service APIs
ensure_apis() {
  step "Enabling APIs: $*"
  GC services enable "$@" --quiet
}

# ensure_sa <sa_id> <display_name> — create a service account if absent
# echoes the full SA email
ensure_sa() {
  local id="$1" name="${2:-$1}" email
  email="${id}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
  if ! GC iam service-accounts describe "$email" >/dev/null 2>&1; then
    GC iam service-accounts create "$id" --display-name "$name" --quiet >/dev/null
    local i
    for i in $(seq 1 12); do
      GC iam service-accounts describe "$email" >/dev/null 2>&1 && break
      sleep 5
    done
    ok "Created SA $email" >&2   # stderr: stdout is this function's return value
  fi
  printf '%s' "$email"
}

# grant_project_role <sa_email> <role> — bind a role at the PROJECT level.
# Use sparingly; prefer resource-level grants below.
grant_project_role() {
  local sa="$1" role="$2"
  GC iam service-accounts describe "$sa" >/dev/null 2>&1 || die "No such SA: $sa"
  _iam_retry "grant $role to $sa" \
    GC projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member "serviceAccount:${sa}" --role "$role" --condition=None --quiet >/dev/null
  ok "Granted $role to $sa (project scope)"
}

# grant_secret_role <secret> <sa_email> <role> — resource-scoped secret grant
grant_secret_role() {
  local secret="$1" sa="$2" role="${3:-roles/secretmanager.secretAccessor}"
  _iam_retry "grant $role on secret:$secret to $sa" \
    GC secrets add-iam-policy-binding "$secret" \
    --member "serviceAccount:${sa}" --role "$role" --quiet >/dev/null
  ok "Granted $role on secret:$secret to $sa"
}

# grant_sa_impersonation <target_sa> <actor_sa> [role] — let actor impersonate target
grant_sa_impersonation() {
  local target="$1" actor="$2" role="${3:-roles/iam.serviceAccountTokenCreator}"
  _iam_retry "allow $actor to impersonate $target" \
    GC iam service-accounts add-iam-policy-binding "$target" \
    --member "serviceAccount:${actor}" --role "$role" --quiet >/dev/null
  ok "$actor may impersonate $target ($role)"
}

# ensure_secret <name> <value> — create/replace a secret's latest version
ensure_secret() {
  local name="$1" value="$2"
  if ! GC secrets describe "$name" >/dev/null 2>&1; then
    GC secrets create "$name" --replication-policy=user-managed \
      --locations "$GCP_REGION" --quiet >/dev/null
    ok "Created secret $name"
  fi
  printf '%s' "$value" | GC secrets versions add "$name" --data-file=- --quiet >/dev/null
  ok "Added version to secret $name"
}

# ensure_bucket <bucket> [public] — create a regional bucket; "public" => allUsers read
ensure_bucket() {
  local bucket="$1" public="${2:-}"
  local uri="gs://${bucket}"
  if ! GS ls -b "$uri" >/dev/null 2>&1; then
    GS mb -p "$GCP_PROJECT_ID" -l "$GCP_REGION" -b on "$uri" >/dev/null
    ok "Created bucket $uri" >&2   # stderr: stdout is this function's return value
  fi
  if [[ "$public" == "public" ]]; then
    # Intentionally public — this is the vulnerability for challenge 01.
    GS iam ch allUsers:objectViewer "$uri" >/dev/null
    warn "Bucket $uri is PUBLIC (allUsers:objectViewer) — challenge-intended"
  fi
  printf '%s' "$uri"
}

# make_sa_key <sa_email> <out_path> — export a JSON key (challenge-intended leak)
make_sa_key() {
  local sa="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  GC iam service-accounts keys create "$out" --iam-account "$sa" --quiet >/dev/null
  chmod 600 "$out"
  ok "Wrote SA key for $sa -> $out"
}

# delete_sa <sa_email> — best-effort delete
delete_sa() { GC iam service-accounts delete "$1" --quiet >/dev/null 2>&1 || true; }
# delete_secret <name>
delete_secret() { GC secrets delete "$1" --quiet >/dev/null 2>&1 || true; }
# delete_bucket <bucket>
delete_bucket() { GS -m rm -r "gs://$1" >/dev/null 2>&1 || true; GS rb "gs://$1" >/dev/null 2>&1 || true; }

# vm_exists <name>
vm_exists() { GC compute instances describe "$1" --zone "$GCP_ZONE" >/dev/null 2>&1; }
# vm_ip <name> — external IP
vm_ip() { GC compute instances describe "$1" --zone "$GCP_ZONE" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'; }
