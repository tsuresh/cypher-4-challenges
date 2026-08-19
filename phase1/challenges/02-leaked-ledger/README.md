# 02 — Leaked Ledger (Highland Leaf)

**Category:** Web / secrets exposure · **Difficulty:** Easy · **Points:** 75 (dynamic)

## Intended solve
1. Browse to the site at `http://<vm-ip>:8002/`.
2. Request the configuration file directly: `curl http://<vm-ip>:8002/.env`.
3. The `.env` is served as plain text and contains `CTF_FLAG=CYPHER{...}`.

## What's under test
Dotfiles (`.env`) served from web root instead of being denied. A hardened
site returns 404 for `location ~ /\.` — this one doesn't (see `default.conf`).

## Infra
- `nginx:alpine` static site.
- The flag is written into `/.env` at container start by `docker-entrypoint.sh`
  from the `CHAL_FLAG` env var, so it is never baked into an image layer or git.

## Remediation (for the Blue Team Brief, challenge 12)
Deny access to dotfiles at the proxy; keep secrets in a secret manager, not on
the filesystem web root; scope the app's credentials to least privilege.
