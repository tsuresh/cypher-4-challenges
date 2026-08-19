# 09 — Peering Into the Cluster (Ape Ride)

**Category:** Kubernetes (read-only) · **Difficulty:** Medium · **Points:** 175 (dynamic)

## Intended solve
1. Browse `https://<vm-ip>:8009/` (self-signed cert — accept it).
2. Click **Skip** on the login screen.
3. Navigate to **Secrets** → namespace `aperide` → `driver-config`.
4. Reveal/decode the `flag` value → `CYPHER{...}`.

CLI alternative once you notice anonymous read:
`kubectl --insecure-skip-tls-verify get secret -n aperide driver-config -o jsonpath='{.data.flag}' | base64 -d`

## Infra & safety
- Local **kind** cluster on the VM (`setup-kind.sh`) — no GKE, nothing billable.
- Vulnerability = Dashboard `--enable-skip-login` + its ServiceAccount granted
  cluster-wide `get/list` on Secrets (`rbac.yaml`).
- Flag stored as a Kubernetes Secret; value comes from run-time `CHAL_FLAG`.

## Remediation (Blue Team Brief)
Disable dashboard skip-login; bind the dashboard SA to a minimal namespaced role
that cannot read Secrets; never expose the dashboard publicly; use RBAC least
privilege and audit ClusterRoleBindings.
