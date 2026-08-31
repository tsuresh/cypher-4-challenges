#!/usr/bin/env python3
"""h01 Token Relay — a 'webhook validator' that fetches a URL server-side and
reflects the response BODY (semi-blind, so token exfil is fair under clock). Runs on
the finals VM whose SA begins a two-hop impersonation chain."""
import os, requests
from urllib.parse import urlparse
from flask import Flask, request, Response

app = Flask(__name__)

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
    headers = {}
    host = (urlparse(url).hostname or "")
    if host in ("169.254.169.254", "metadata.google.internal"):
        headers["Metadata-Flavor"] = "Google"
    try:
        r = requests.get(url, headers=headers, timeout=5, allow_redirects=True)
        # semi-blind: reflect status AND body
        return Response(f"Webhook check for {url}\nHTTP {r.status_code}\n---\n{r.text}\n",
                        mimetype="text/plain")
    except Exception as e:
        return Response(f"unreachable: {e}\n", status=502, mimetype="text/plain")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
