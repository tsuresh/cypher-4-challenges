# 07 — Too Many Permissions (Ruhunu Bank)

**Category:** Cloud IAM · **Difficulty:** Medium · **Points:** 150 (dynamic)

## Intended solve
```sh
gcloud auth activate-service-account --key-file=ruhunu-analyst-sa-key.json
gcloud config set project <sandbox-project>
gcloud secrets versions access latest --secret=ruhunu-analytics-flag   # CYPHER{...}
```
Teams learn to introspect an identity (`gcloud secrets list`, testable-permissions)
then use the one grant it has.

## Infra & safety
- Secret Manager secret `ruhunu-analytics-flag` = the flag (from `CHAL_FLAG`).
- SA `ruhunu-analyst` granted **only** `secretAccessor` on **that one secret** —
  resource-scoped, no project roles. Leaking the key reaches nothing else.
- The SA key is generated at provision time and attached as a challenge file
  (gitignored: `*-sa-key.json`).

## Remediation (Blue Team Brief)
Grant roles at the resource, not the project; avoid long-lived SA keys (use
workload identity / short-lived tokens); rotate and monitor key usage.
