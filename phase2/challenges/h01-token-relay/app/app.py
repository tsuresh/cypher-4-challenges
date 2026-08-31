#!/usr/bin/env python3
"""h01 Token Relay — a 'webhook validator' that fetches a URL server-side and
reflects the response BODY (semi-blind, so token exfil is fair under clock). Runs on
the finals VM whose SA begins a two-hop impersonation chain."""
import os, socket, ipaddress, requests
from urllib.parse import urlparse
from flask import Flask, request, Response

app = Flask(__name__)

# Semi-blind SSRF intended to reach the GCE metadata server ONLY. Block all other
# private/loopback/link-local targets (no pivot to CTFd / other containers / other
# teams) and cap the reflected body (no OOM DoS on the shared host).
METADATA_HOSTS = {"169.254.169.254", "metadata.google.internal"}
MAX_BYTES = 64 * 1024

def ssrf_ok(host: str):
    if not host:
        return False, "no host"
    if host in METADATA_HOSTS:
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
    r = requests.get(url, headers=headers, timeout=5, allow_redirects=False, stream=True)
    body, total = [], 0
    for chunk in r.iter_content(8192):
        body.append(chunk); total += len(chunk)
        if total >= MAX_BYTES:
            break
    return r.status_code, b"".join(body)[:MAX_BYTES].decode("utf-8", "replace")

@app.get("/")
def home():
    return Response("Ape Ride webhook validator.\n"
                    "GET /validate?url=<url> — we fetch it and show you the response.\n",
                    mimetype="text/plain")

@app.get("/validate")
def validate():
    url = request.args.get("url", "")
    if not url:
        return Response("provide ?url=", status=400)
    host = (urlparse(url).hostname or "")
    ok, why = ssrf_ok(host)
    if not ok:
        return Response(f"refused: {why}\n", status=400, mimetype="text/plain")
    headers = {}
    if host in METADATA_HOSTS:
        headers["Metadata-Flavor"] = "Google"
    try:
        code, text = fetch(url, headers)
        return Response(f"Webhook check for {url}\nHTTP {code}\n---\n{text}\n",
                        mimetype="text/plain")
    except Exception as e:
        return Response(f"unreachable: {e}\n", status=502, mimetype="text/plain")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
