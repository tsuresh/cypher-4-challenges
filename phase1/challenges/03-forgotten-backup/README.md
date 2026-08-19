# 03 — The Forgotten Backup (Pearl Telecom)

**Category:** Web / recon · **Difficulty:** Easy · **Points:** 100 (dynamic)

## Intended solve
1. Guess common backup locations: `/backup.sql`, `/db_backup.sql`, `/backups/`.
2. `curl http://<vm-ip>:8003/backups/db_backup.sql`.
3. The dump contains `INSERT INTO app_config VALUES ('build_flag','CYPHER{...}')`.

## Infra
- `nginx:alpine` static site; the backup file is written at container start from
  `CHAL_FLAG` (`docker-entrypoint.sh`), so the flag is not in the image or git.

## Remediation (Blue Team Brief)
Never leave backups under the web root; store them off-host with access control;
add a deny rule for `*.sql`, `*.bak`, `*.zip`; use predictable-path scanning in CI.
