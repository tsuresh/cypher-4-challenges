#!/bin/sh
# Build a git repo in the web root at container start: commit a secrets file
# carrying the run-time flag, then "remove" it in a later commit. The .git
# directory is served, so the flag is recoverable from history (git log -p),
# not from the current working tree.
set -e
: "${CHAL_FLAG:?CHAL_FLAG must be provided}"

WEB=/usr/share/nginx/html
rm -rf "$WEB"; mkdir -p "$WEB"
cp -a /seed/. "$WEB/"

cd "$WEB"
git init -q
git config user.email "dev@pearltelecom.lk"
git config user.name "Pearl Telecom Dev"
git add index.html
git commit -q -m "Initial commit: launch static site"

# The mistake: a config file with a secret gets committed...
cat > config.php <<EOF
<?php
// Pearl Telecom API integration (staging)
define('API_TOKEN', '${CHAL_FLAG}');
define('API_BASE', 'https://api.pearltelecom.lk/v1');
EOF
git add config.php
git commit -q -m "Add API integration config"

# ...then "removed" in a cleanup commit — but it stays in history.
git rm -q config.php
git commit -q -m "Remove secret config before public launch (oops, history remains)"

# Make sure the served tree does NOT contain config.php, only .git history does.
rm -f "$WEB/config.php"
