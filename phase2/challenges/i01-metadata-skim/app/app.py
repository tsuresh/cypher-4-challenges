#!/usr/bin/env python3
"""i01 Metadata Skim — a server-side URL previewer (SSRF). It fetches the URL you
give it and returns the body, auto-adding Metadata-Flavor: Google for the GCE
metadata host (as a convenience the real Ape Ride tool had). Runs on a GCE VM whose
service account is scoped to exactly one flag resource."""
import os, socket, ipaddress, requests
from urllib.parse import urlparse
from flask import Flask, request, Response

app = Flask(__name__)

# The challenge intends SSRF to the GCE metadata server ONLY. Everything else
# private/loopback/link-local is blocked so a team cannot pivot to CTFd, other
# challenge containers, or other teams' instances (blast-radius containment), and
# responses are size-capped so a huge fetch cannot OOM the shared host (DoS).
METADATA_HOSTS = {"169.254.169.254", "metadata.google.internal"}
MAX_BYTES = 64 * 1024

def ssrf_ok(host: str):
    if not host:
        return False, "no host"
    if host in METADATA_HOSTS:                       # the one intended target
        return True, ""
    try:
        addrs = {ai[4][0] for ai in socket.getaddrinfo(host, None)}
    except Exception:
        return False, "resolve failed"
    for a in addrs:
        ip = ipaddress.ip_address(a)
        if (ip.is_private or ip.is_loopback or ip.is_link_local or
                ip.is_reserved or ip.is_multicast or ip.is_unspecified):
            return False, "blocked: internal/private target"
    return True, ""

def fetch(url, headers):
    # no redirects (blocks redirect-to-internal bypass); stream + hard size cap
    r = requests.get(url, headers=headers, timeout=5, allow_redirects=False, stream=True)
    body, total = [], 0
    for chunk in r.iter_content(8192):
        body.append(chunk); total += len(chunk)
        if total >= MAX_BYTES:
            break
    return r.status_code, b"".join(body)[:MAX_BYTES].decode("utf-8", "replace")

@app.get("/")
def home():
    return Response("Ape Ride document previewer.\n"
                    "GET /preview?url=<url>  — fetches the document server-side.\n",
                    mimetype="text/plain")

@app.get("/preview")
def preview():
    url = request.args.get("url", "")
    if not url:
        return Response("provide ?url=", status=400)
    host = (urlparse(url).hostname or "")
    ok, why = ssrf_ok(host)
    if not ok:
        return Response(f"refused: {why}\n", status=400, mimetype="text/plain")
    headers = {}
    if host in METADATA_HOSTS:
        headers["Metadata-Flavor"] = "Google"        # convenience -> enables the SSRF-to-token
    try:
        code, text = fetch(url, headers)
        return Response(f"Fetched {url} (HTTP {code}):\n\n{text}\n", mimetype="text/plain")
    except Exception as e:
        return Response(f"fetch error: {e}\n", status=502, mimetype="text/plain")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
