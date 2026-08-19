# 01 — The Open Warehouse (Ceylon Kade)

**Category:** Cloud storage / recon · **Difficulty:** Easy · **Points:** 75 (dynamic)

## Intended solve
```sh
gsutil ls -r gs://<project>-ck-warehouse
gsutil cat gs://<project>-ck-warehouse/inventory/internal-notes.txt   # launch token: CYPHER{...}
```
(Anonymous access works too: the bucket is `allUsers:objectViewer`.)

## Infra & safety
- One regional GCS bucket made **public** (`allUsers:objectViewer`) by `provision.sh`.
- Flag written into `inventory/internal-notes.txt` from run-time `CHAL_FLAG`.
- No service account or token is exposed — the only thing leaked is this bucket.

## Remediation (Blue Team Brief)
Never grant `allUsers`; enable Public Access Prevention org policy; use uniform
bucket-level access + IAM; separate public assets from internal notes.
