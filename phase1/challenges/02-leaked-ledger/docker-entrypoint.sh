#!/bin/sh
# Render the "accidentally committed" .env at container start using the
# run-time flag, so the flag never sits in the image layers or git.
set -e
: "${CHAL_FLAG:?CHAL_FLAG must be provided}"
cat > /usr/share/nginx/html/.env <<EOF
# Highland Leaf — production config (DO NOT COMMIT)
APP_ENV=production
APP_DEBUG=false
DB_HOST=10.20.0.14
DB_NAME=highland_ledger
DB_USER=ledger_app
DB_PASS=Le@fL3dg3r!2026
MAIL_DSN=smtp://ledger:hunter2@mail.highlandleaf.lk:587
# internal build note left by an intern:
CTF_FLAG=${CHAL_FLAG}
EOF
