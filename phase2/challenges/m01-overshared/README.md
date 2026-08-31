# m01 — Overshared (Ceylon Kade)

**Category:** Cloud Storage / IAM · **Difficulty:** Medium · **Points:** 250 (dynamic)

## Intended solve
```sh
# The bucket is NOT anonymous-public. gsutil as no-one fails:
gsutil ls gs://<bucket>/                          # AccessDeniedException (anonymous)

# But it grants allAuthenticatedUsers — ANY Google identity, not just this org.
# Authenticate with any throwaway Google account (or the provided sandbox login):
gcloud auth login                                 # any google.com account works
gsutil ls -r gs://<bucket>/                        # now it lists
gsutil cat gs://<bucket>/finance/reconciliation.csv | grep CYPHER   # CYPHER{...}
```
The trap: teams try anonymous access, get denied, and conclude it's locked. `allAuthenticatedUsers`
is **not** "your organisation" — it is *every* Google account on the planet.

## Infra & safety
- One GCS bucket with IAM `allAuthenticatedUsers:objectViewer` (+ list). No `allUsers`.
- **Shared** challenge, **per-team unique flag** (`unique_flag m01 <team>`).
- The object holds only the flag + decoy finance rows; the binding reaches nothing else.

## Remediation (Blue Team Brief)
`allAuthenticatedUsers` is public-with-a-login, not internal. Prefer named groups/SAs; enforce
Domain Restricted Sharing and `storage.publicAccessPrevention`; alert on both `allUsers` **and**
`allAuthenticatedUsers` bindings in IAM policy scans.
