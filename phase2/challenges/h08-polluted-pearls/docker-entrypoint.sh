#!/bin/sh
set -e
: "${FLAG:?FLAG required}"
printf '%s\n' "$FLAG" > /flag
chmod 644 /flag
exec node server.js
