#!/usr/bin/env python3
"""h14 Paper Trail — generate a synthetic GCP Cloud Audit Log bundle in which the
flag is recoverable ONLY by tracing the attack chain:

  external login  ->  SetIamPolicy (grants tokenCreator to attacker principal)
                  ->  GenerateAccessToken (attacker impersonates a privileged SA)
                  ->  AccessSecretVersion (the impersonated SA exfiltrates a secret)

The real AccessSecretVersion sits among many decoys; its request carries the flag
base64-encoded in a custom label, so it is not grep-able as a literal and can only
be picked out by following the chain. Usage: gen.py 'CYPHER{...}' out.tar.gz
"""
import sys, os, json, base64, random, tarfile, io, ipaddress
from datetime import datetime, timedelta

def ts(base, sec):
    return (base + timedelta(seconds=sec)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

def entry(method, principal, resource, when, ip="10.10.0.5", extra=None):
    e = {
        "protoPayload": {
            "@type": "type.googleapis.com/google.cloud.audit.AuditLog",
            "methodName": method,
            "authenticationInfo": {"principalEmail": principal},
            "requestMetadata": {"callerIp": ip},
            "resourceName": resource,
        },
        "timestamp": when,
        "severity": "NOTICE",
    }
    if extra:
        e["protoPayload"].update(extra)
    return e

def main():
    flag = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "audit-logs.tar.gz"
    rnd = random.Random(flag)                      # deterministic per flag
    base = datetime(2026, 9, 5, 9, 13, 0)
    proj = "ape-ride-prod"
    ext_ip = "203.0.113." + str(rnd.randint(20, 240))

    attacker = "ci-runner@%s.iam.gserviceaccount.com" % proj      # compromised low-priv
    priv_sa  = "billing-admin@%s.iam.gserviceaccount.com" % proj  # the juicy identity
    real_secret = "customer-pii-export"

    entries = []
    # noise: lots of benign activity across many principals/secrets
    people = [f"eng{n}@ape-ride.lk" for n in range(1, 9)]
    secrets = ["analytics-token", "map-api-key", "sms-gateway-key", "cache-pw",
               "invoice-signing", "partner-webhook", real_secret, "legacy-db-pw"]
    for i in range(120):
        who = rnd.choice(people + [attacker, priv_sa])
        sec = rnd.choice(secrets)
        entries.append(entry(
            "google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion",
            who, f"projects/{proj}/secrets/{sec}/versions/1",
            ts(base, rnd.randint(-3600, 3600)),
            ip=f"10.10.0.{rnd.randint(2,250)}"))

    # THE CHAIN (t0..t3), the only path that matters:
    # 1) attacker principal authenticates from an EXTERNAL ip
    entries.append(entry("google.iam.admin.v1.ListServiceAccounts", attacker,
                         f"projects/{proj}", ts(base, 0), ip=ext_ip))
    # 2) SetIamPolicy grants attacker tokenCreator on the privileged SA
    entries.append(entry("google.iam.admin.v1.SetIAMPolicy", attacker,
                         f"projects/{proj}/serviceAccounts/{priv_sa}", ts(base, 30),
                         ip=ext_ip,
                         extra={"serviceData": {"policyDelta": {"bindingDeltas": [
                             {"action": "ADD", "role": "roles/iam.serviceAccountTokenCreator",
                              "member": f"serviceAccount:{attacker}"}]}}}))
    # 3) attacker impersonates priv_sa (GenerateAccessToken names the delegate)
    entries.append(entry("google.iam.credentials.v1.GenerateAccessToken", attacker,
                         f"projects/{proj}/serviceAccounts/{priv_sa}", ts(base, 61),
                         ip=ext_ip,
                         extra={"request": {"name": f"projects/-/serviceAccounts/{priv_sa}",
                                             "delegates": []}}))
    # 4) the impersonated SA reads the real secret — flag hidden here (base64 label)
    entries.append(entry(
        "google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion",
        priv_sa, f"projects/{proj}/secrets/{real_secret}/versions/3", ts(base, 92),
        ip=ext_ip,
        extra={"metadata": {"exfilMarker": base64.b64encode(flag.encode()).decode()}}))

    rnd.shuffle(entries)
    # split across a few daily files like a real export
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for fi in range(4):
            chunk = entries[fi::4]
            data = ("\n".join(json.dumps(e) for e in chunk)).encode()
            info = tarfile.TarInfo(f"logs/cloudaudit.googleapis.com/activity-2026-09-05-{fi}.json")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    open(out, "wb").write(buf.getvalue())
    print(f"wrote {out} ({len(entries)} entries, ext_ip={ext_ip})")

if __name__ == "__main__":
    main()
