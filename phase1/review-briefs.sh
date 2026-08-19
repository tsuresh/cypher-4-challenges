#!/usr/bin/env bash
# phase1/review-briefs.sh — pull every Blue Team Brief (12) submission for the
# SCTF panel's secondary tie-break review. Read-only; prints team + text.
#
# Needs CTFD_URL + CTFD_ADMIN_TOKEN (export them, or they're read from provision).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
load_env
require curl python3
: "${CTFD_URL:=http://localhost:8000}"
: "${CTFD_ADMIN_TOKEN:?export CTFD_ADMIN_TOKEN (from provision.sh output)}"

step "Fetching Blue Team Brief submissions from $CTFD_URL"
curl -fsS -H "Authorization: Token ${CTFD_ADMIN_TOKEN}" \
  "${CTFD_URL}/api/v1/submissions?per_page=200" \
| python3 - "$CTFD_URL" "$CTFD_ADMIN_TOKEN" <<'PY'
import json, sys, urllib.request
url, token = sys.argv[1], sys.argv[2]
subs = json.load(sys.stdin)["data"]
# find the Blue Team Brief challenge id
req = urllib.request.Request(url + "/api/v1/challenges?view=admin",
                             headers={"Authorization": f"Token {token}"})
chals = json.load(urllib.request.urlopen(req))["data"]
brief = next((c for c in chals if "Blue Team Brief" in c["name"]), None)
if not brief:
    print("Blue Team Brief challenge not found."); sys.exit(0)
rows = [s for s in subs if s.get("challenge_id") == brief["id"]]
print(f"{len(rows)} submission(s) for '{brief['name']}':\n")
for s in rows:
    who = s.get("team", s.get("user", "?"))
    print(f"--- team={who}  type={s.get('type')}  at={s.get('date')}")
    print(s.get("provided", "").strip(), "\n")
PY
