#!/bin/sh
set -e
: "${FLAG:?FLAG required}"
exec gunicorn -b 0.0.0.0:8000 --workers 1 --threads 8 --timeout 30 \
  --access-logfile - --error-logfile - app:app
