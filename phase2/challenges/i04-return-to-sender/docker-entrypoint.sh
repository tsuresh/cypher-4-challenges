#!/bin/sh
# Inject the per-team flag at runtime (never in an image layer), then serve.
set -e
: "${FLAG:?FLAG required}"
printf '%s\n' "$FLAG" > /flag
chmod 644 /flag
# max-children caps concurrent connections (fork-flood DoS); the binary's own
# alarm(60) bounds each session. Combine with container pids/mem limits (see whale).
exec socat TCP-LISTEN:9104,reuseaddr,fork,max-children=48 EXEC:/return-to-sender,stderr
