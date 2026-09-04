# ctfd-whale — per-team instance configuration

The per-team container challenges are spawned on demand by **ctfd-whale**. After the
platform is up (`docker compose up -d` here) and CTFd is bootstrapped, configure whale
in **Admin → Plugins → Whale → Settings** (or via the CTFd config API):

| Setting | Value |
|---|---|
| Docker API URL | `unix:///var/run/docker.sock` |
| Auto-connect network | `cypher-p2-whale` |
| FRP direct-TCP address | the finals VM external IP |
| FRP API URL / token | frps at `frps:7000`, token = `FRP_TOKEN` from `.env` |
| Port range | `10000-10100` (matches `frps.ini` + the `cypher-allow-whale` firewall rule) |
| Max container count | ≥ (teams × per-team-challenges), e.g. 10 × 8 = 80 |
| Per-container timeout | e.g. 3600 s (renewable) |

## Per-challenge whale entries (image + hard limits)

Register each as a **dynamic_docker** challenge pointing at the image below. The limits
implement `phase2/SECURITY.md §1` (stop one team's RCE/fork-bomb taking down the node):

| ID | Image | Internal port | mem_limit | cpu | pids |
|----|-------|---------------|-----------|-----|------|
| e02 | `cypher-p2/e02:latest` | 8000 | 256m | 0.5 | 128 |
| i02 | `cypher-p2/i02:latest` | 8000 | 256m | 0.5 | 128 |
| i04 | `cypher-p2/i04:latest` | 9104 | 256m | 0.5 | 128 |
| m03 | `cypher-p2/m03:latest` | 8000 | 256m | 0.5 | 128 |
| h06 | `cypher-p2/h06:latest` | 8000 | 256m | 0.5 | 128 |
| h08 | `cypher-p2/h08:latest` | 8000 | 256m | 0.5 | 128 |
| h10 | `cypher-p2/h10:latest` | 8000 | 256m | 0.5 | 128 |
| h16 | `cypher-p2/h16:latest` | (escape sandbox) | 512m | 1.0 | 256 |

The per-team **flag** is injected via the container env `FLAG` (whale supports per-team flag
env). For h16, launch inside the **nested sandbox** (SECURITY.md §5) — do **not** run the
privileged container directly on the finals host.

## NOT whale — dedicated scoped-SA VMs (i01, h01)

`i01` and `h01` are SSRF challenges whose intended target is the GCE metadata server. A
container on the finals VM would reach the **finals VM's** SA (SECURITY.md §3), so these run
on their **own small GCE VM(s)** with the scoped SA attached:

- **i01** VM SA = `aperide-preview@<proj>` (objectViewer on its flag bucket). App on `:8101`.
- **h01** VM SA = `webhook-runner@<proj>` (starts the impersonation chain). App on `:8001`.

Deploy: create a small VM per challenge (or per team for true isolation), attach the SA
(`--service-account`), run the image (`cypher-p2/i01` / `cypher-p2/h01`) with `FLAG` unset
(the flag is read from the scoped resource, not the app). Point the CTFd challenge's
`connection_info` at `http://<that-vm-ip>:<port>/`.

## NOT whale either — shared instances on the platform VM (ai1, ai2, ai3)

The three AI-security challenges are deterministic mock-LLMs (regex-based, no real model API
calls, no per-request state) — one shared container per challenge serves every team, same as
e01/m01 conceptually but backed by an actual app instead of a bare cloud resource. Each has
its own `provision.sh` (mirroring i01/h01's shape) that `docker run`s the image directly on
`cypher-phase2` with the §1 hard limits, on a fixed port, and prints `CONNECT=`:

| ID | Image | Port | mem_limit | cpu | pids |
|----|-------|------|-----------|-----|------|
| ai1 | `cypher-p2/ai1:latest` | 8020 | 256m | 0.5 | 128 |
| ai2 | `cypher-p2/ai2:latest` | 8021 | 256m | 0.5 | 128 |
| ai3 | `cypher-p2/ai3:latest` | 8022 | 256m | 0.5 | 128 |
