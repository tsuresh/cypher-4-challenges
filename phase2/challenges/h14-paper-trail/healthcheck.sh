#!/usr/bin/env bash
# h14 healthcheck / scripted solve: build the log bundle for a test flag, then
# reconstruct the attack chain (external-IP principal -> SetIamPolicy grant ->
# GenerateAccessToken impersonation -> AccessSecretVersion exfil), pick the real
# secret read out of the decoys, decode the flag, and confirm it matches.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{ape_ride_audit_chain_traced}'
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PY=""; [ -x "$HERE/../../../.venv/bin/python" ] && PY="$HERE/../../../.venv/bin/python" || PY=python3

"$PY" "$HERE/gen.py" "$FLAG" "$WORK/audit-logs.tar.gz" >/dev/null

REC="$("$PY" - "$WORK/audit-logs.tar.gz" <<'PY'
import sys, json, tarfile, base64, ipaddress
tar=tarfile.open(sys.argv[1]); E=[]
for m in tar.getmembers():
    for line in tar.extractfile(m).read().decode().splitlines():
        if line.strip(): E.append(json.loads(line))
def pp(e): return e["protoPayload"]
_PRIV=[ipaddress.ip_network(c) for c in ("10.0.0.0/8","172.16.0.0/12","192.168.0.0/16")]
def external(ip):
    try:
        a=ipaddress.ip_address(ip); return not any(a in n for n in _PRIV)
    except ValueError: return False

# 1) find the principal acting from an external IP via SetIamPolicy that grants tokenCreator
grant=[e for e in E if pp(e)["methodName"].endswith("SetIAMPolicy")
       and external(pp(e)["requestMetadata"]["callerIp"])]
assert grant, "no external SetIamPolicy found"
g=grant[0]; attacker=pp(g)["authenticationInfo"]["principalEmail"]
priv_sa=pp(g)["resourceName"].split("/serviceAccounts/")[1]

# 2) confirm impersonation of priv_sa by attacker
imp=[e for e in E if pp(e)["methodName"].endswith("GenerateAccessToken")
     and pp(e)["authenticationInfo"]["principalEmail"]==attacker
     and priv_sa in pp(e)["resourceName"]]
assert imp, "no impersonation of the granted SA"

# 3) the exfil read: AccessSecretVersion performed BY the impersonated SA
reads=[e for e in E if pp(e)["methodName"].endswith("AccessSecretVersion")
       and pp(e)["authenticationInfo"]["principalEmail"]==priv_sa]
assert len(reads)>=1, "no secret read by the impersonated SA"
# among those, the one carrying the exfil marker
marker=None
for e in reads:
    md=pp(e).get("metadata",{})
    if "exfilMarker" in md: marker=md["exfilMarker"]; break
assert marker, "no exfil marker on the impersonated read"
sys.stdout.write(base64.b64decode(marker).decode())
PY
)"
echo "recovered: $REC"
[[ "$REC" == "$FLAG" ]] && { echo "h14 healthcheck rc=0"; exit 0; }
echo "h14 healthcheck FAILED (got: $REC)"; exit 1
