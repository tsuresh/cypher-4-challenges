# 04 — Metadata Mischief (Ape Ride)

**Category:** SSRF / cloud metadata · **Difficulty:** Medium · **Points:** 150 (dynamic)

## Intended solve
1. Open the preview tool at `http://<vm-ip>:8004/`.
2. Submit `url=http://169.254.169.254/computeMetadata/v1/instance/attributes/cypher-flag-04`.
3. The app fetches it (adding `Metadata-Flavor: Google` for you) and echoes the flag.

Teams can also explore `/computeMetadata/v1/` to see the tree — good teaching moment.

## Infra & safety
- Flask SSRF app (`gunicorn`) on port 8004. **Must run on the GCE VM** so the
  real metadata server is reachable.
- The flag is a **custom instance-metadata attribute** (`cypher-flag-04`) set by
  `provision.sh`. The VM service account stays scoped to nothing project-wide, so
  reading metadata yields only this attribute — never a token to broader access.

## Remediation (Blue Team Brief)
Block egress to 169.254.169.254 from app workloads; validate/allow-list fetch
targets; require GCE metadata `Metadata-Flavor` never be auto-added; prefer
GKE Workload Identity / metadata concealment.
