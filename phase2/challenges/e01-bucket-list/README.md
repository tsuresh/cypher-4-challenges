# e01 — Bucket List (Arugam Waves)

**Category:** Cloud Storage / Recon · **Difficulty:** Easy · **Points:** 200 (dynamic)

## Intended solve
```sh
# The surf-cam startup left its media bucket world-readable AND listable.
gsutil ls -r gs://<bucket>/                      # or the JSON API, unauthenticated
#   -> among the surf photos sits an out-of-place object, e.g. ops/handover.txt
gsutil cat gs://<bucket>/ops/handover.txt        # CYPHER{...}
```
No credentials needed — `allUsers` holds both `roles/storage.objectViewer` and list access, so
anyone can enumerate and read.

## Infra & safety
- One GCS bucket in the sandbox project, IAM `allUsers:objectViewer` + legacy list. The flag
  object is the only sensitive content; everything else is decoy media.
- **Shared** challenge with a **per-team unique flag** (`unique_flag e01 <team>`), so the object
  body is rendered per team at provision — no live flag is shareable.
- Bucket holds no keys or tokens; reading it reaches nothing beyond this one object.

## Remediation (Blue Team Brief)
Never grant `allUsers` on a bucket; audit public IAM with `gsutil iam get` and Org Policy
`storage.publicAccessPrevention`; separate public web assets from operational files.
