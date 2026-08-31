#!/bin/sh
# Inject the per-team flag at runtime (never in an image layer), then serve.
set -e
: "${FLAG:?FLAG required}"
printf '%s\n' "$FLAG" > /flag
chmod 644 /flag
exec socat TCP-LISTEN:9104,reuseaddr,fork EXEC:/return-to-sender,pty,stderr
