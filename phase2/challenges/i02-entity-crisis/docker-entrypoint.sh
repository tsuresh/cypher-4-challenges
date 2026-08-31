#!/bin/sh
set -e
: "${FLAG:?FLAG required}"
printf '%s\n' "$FLAG" > /flag
chmod 644 /flag
exec gunicorn -b 0.0.0.0:8000 --workers 2 --threads 4 --timeout 30 \
  --access-logfile - --error-logfile - app:app
