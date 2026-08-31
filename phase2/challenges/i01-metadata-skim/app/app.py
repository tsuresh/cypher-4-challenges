#!/usr/bin/env python3
"""i01 Metadata Skim — a server-side URL previewer (SSRF). It fetches the URL you
give it and returns the body, auto-adding Metadata-Flavor: Google for the GCE
metadata host (as a convenience the real Ape Ride tool had). Runs on a GCE VM whose
service account is scoped to exactly one flag resource."""
import os, requests
from urllib.parse import urlparse
from flask import Flask, request, Response

app = Flask(__name__)

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
    headers = {}
    host = (urlparse(url).hostname or "")
    if host in ("169.254.169.254", "metadata.google.internal"):
        headers["Metadata-Flavor"] = "Google"        # convenience -> enables the SSRF-to-token
    try:
        r = requests.get(url, headers=headers, timeout=5, allow_redirects=True)
        return Response(f"Fetched {url} (HTTP {r.status_code}):\n\n{r.text}\n",
                        mimetype="text/plain")
    except Exception as e:
        return Response(f"fetch error: {e}\n", status=502, mimetype="text/plain")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
