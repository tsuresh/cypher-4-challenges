#!/bin/sh
# Injects run-time flags so they never live in an image layer or in git.
set -e

: "${FLAG1:?FLAG1 required}"; : "${FLAG2:?FLAG2 required}"; : "${FLAG3:?FLAG3 required}"

DOCS=/srv/lankagov/documents
SECRET=/srv/lankagov/secret
mkdir -p "$DOCS" "$SECRET"

printf 'LankaGov e-Services — issued document placeholder (PDF stub)\n' > "$DOCS/sealed_4471.pdf"
printf 'LankaGov e-Services — driving permit receipt (PDF stub)\n'     > "$DOCS/permit_1001.pdf"

cat > "$SECRET/vault.conf" <<CONF
# LankaGov e-Services — master vault configuration (RESTRICTED)
# If you are reading this over the citizen document endpoint, containment failed.
db_dsn=postgresql://lankagov:REDACTED@db.internal/eservices
session_signing_key=REDACTED
vault_master=${FLAG3}
CONF
chmod 640 "$SECRET/vault.conf"

# Staff key: use the value injected via env (stable across restarts, so a rebuild
# does NOT invalidate keys teams already hold). Fall back to random only if unset.
STAFF_KEY="${STAFF_KEY:-$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
export STAFF_KEY DOCS_DIR="$DOCS"

# gthread with many threads: survives many concurrent / slow clients (teams +
# fuzzers) without the whole app stalling the way 2 sync workers did. Access log
# to stdout for forensics.
exec gunicorn -b 0.0.0.0:8000 \
  --worker-class gthread --workers 3 --threads 8 \
  --timeout 30 --graceful-timeout 30 --keep-alive 2 \
  --worker-tmp-dir /dev/shm \
  --access-logfile - --error-logfile - \
  app:app
