#!/bin/sh
# Injects run-time flags so they never live in an image layer or in git.
set -e

: "${FLAG1:?FLAG1 required}"; : "${FLAG2:?FLAG2 required}"; : "${FLAG3:?FLAG3 required}"

DOCS=/srv/lankagov/documents
SECRET=/srv/lankagov/secret
mkdir -p "$DOCS" "$SECRET"

# Legit citizen-visible documents (decoys) served normally by the endpoint.
printf 'LankaGov e-Services — issued document placeholder (PDF stub)\n' > "$DOCS/sealed_4471.pdf"
printf 'LankaGov e-Services — driving permit receipt (PDF stub)\n'     > "$DOCS/permit_1001.pdf"

# Stage 3 target: the master vault config, ONLY reachable via path traversal
# out of $DOCS into $SECRET. FLAG3 lives here and nowhere else.
cat > "$SECRET/vault.conf" <<CONF
# LankaGov e-Services — master vault configuration (RESTRICTED)
# If you are reading this over the citizen document endpoint, containment failed.
db_dsn=postgresql://lankagov:REDACTED@db.internal/eservices
session_signing_key=REDACTED
vault_master=${FLAG3}
CONF
chmod 640 "$SECRET/vault.conf"

# Shared staff key across all gunicorn workers (Stage 1 leaks it, Stage 2/3 need it).
STAFF_KEY="$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"
export STAFF_KEY DOCS_DIR="$DOCS"

# Two workers is plenty for ~20 teams; single master key shared via env above.
exec gunicorn -b 0.0.0.0:8000 -w 2 --timeout 30 app:app
