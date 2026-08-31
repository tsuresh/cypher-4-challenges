# h14 — Paper Trail (Ape Ride)

**Category:** Forensics / GCP Cloud Audit Logs · **Difficulty:** Hard · **Points:** 400 (dynamic)

## Intended solve
An attacker moved through Ape Ride's GCP project. You get the **Cloud Audit Log** export
(`audit-logs.tar.gz`, newline-delimited JSON). The flag is **not** a literal in the logs — it is
reconstructed by correlating the attack chain.

```sh
tar xzf audit-logs.tar.gz && cd logs
# 1) Find the initial access: which principal first appears from an external IP?
jq 'select(.protoPayload.methodName=="SetIamPolicy")' *.json      # who granted whom what
# 2) Follow the impersonation:
jq 'select(.protoPayload.methodName|test("GenerateAccessToken"))' *.json
#    -> serviceAccount A minted a token for serviceAccount B (note the delegation chain)
# 3) Find the exfil read:
jq 'select(.protoPayload.methodName=="google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion")' *.json
#    -> which secret (resourceName), by which principalEmail, at what time
```
Assemble the flag from the **correlated facts** the challenge defines (e.g. the impersonated SA's
short-id + the accessed secret's short-name + the request's numeric detail), formatted per the
README's stated recipe → `CYPHER{...}`. The point is tracing the chain, not grepping.

## Infra & safety
- **Attachment-only** JSON bundle, generated per team so the correlated flag is unique
  (`unique_flag h14 <team>` seeds the synthetic principals/resources). No live infra.
- Logs are synthetic; no real project identifiers leak.

## Remediation (Blue Team Brief)
Enable Data Access audit logs and export to a tamper-evident sink; alert on `SetIamPolicy`,
`GenerateAccessToken`, and `AccessSecretVersion` from unusual principals/IPs; monitor SA
impersonation chains — they are lateral-movement edges.
