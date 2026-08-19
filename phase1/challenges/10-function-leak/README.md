# 10 — Function Leak (Ruhunu Bank)

**Category:** Serverless · **Difficulty:** Medium · **Points:** 150 (dynamic)

## Intended solve
```sh
curl "<function-url>?template={env}"
# ...prints the environment dict, including FLAG': 'CYPHER{...}'
```
Bonus teaching: `?template={env[FLAG]}` prints just the flag.

## Infra & safety
- Cloud Function gen2 (`ruhunu-greeting`), `--allow-unauthenticated`, `max-instances 3`.
- Flag is passed as the `FLAG` env var from run-time `CHAL_FLAG`.
- Vulnerability: user-controlled `str.format()` template with `env` exposed
  (`src/main.py`) — Python format-string injection.

## Remediation (Blue Team Brief)
Never format untrusted templates; keep secrets out of function env (use Secret
Manager at call time); validate/allow-list input; require auth on internal funcs.
