"""
Ape Ride — "Driver Photo Preview" service.

A convenience endpoint fetches a URL server-side and shows the response, so
support staff can preview a driver's uploaded document by link. There is no
egress filtering, so the fetch can be pointed at the cloud metadata server
(169.254.169.254 / metadata.google.internal) — a classic SSRF.

Intended solve:
  POST url=http://169.254.169.254/computeMetadata/v1/instance/attributes/cypher-flag-04
The app helpfully adds the `Metadata-Flavor: Google` header for google metadata
hosts (a real-world "dev convenience" footgun), so the attribute — the flag,
planted as a custom instance-metadata attribute by provision.sh — comes back.
"""
import ipaddress
import socket
from urllib.parse import urlparse

import requests
from flask import Flask, request

app = Flask(__name__)

PAGE = """<!doctype html><html><head><meta charset=utf-8>
<title>Ape Ride — Document Preview</title>
<style>body{{font-family:system-ui;background:#101418;color:#e6edf3;max-width:760px;margin:2rem auto;padding:0 1rem}}
input{{width:100%;padding:.6rem;border-radius:8px;border:1px solid #30363d;background:#0d1117;color:#e6edf3}}
button{{margin-top:.6rem;padding:.6rem 1rem;border:0;border-radius:8px;background:#238636;color:#fff}}
pre{{background:#0d1117;border:1px solid #30363d;padding:1rem;border-radius:8px;overflow:auto}}
h1{{font-size:1.3rem}}</style></head><body>
<h1>🚗 Ape Ride — Driver Document Preview</h1>
<p>Paste the URL of a driver's uploaded document to preview it.</p>
<form method=post><input name=url placeholder="https://..." value="{url}">
<button>Preview</button></form>
{result}
</body></html>"""


def is_google_metadata(host: str) -> bool:
    if host in ("metadata.google.internal", "metadata"):
        return True
    try:
        return ipaddress.ip_address(socket.gethostbyname(host)) == ipaddress.ip_address("169.254.169.254")
    except Exception:
        return host == "169.254.169.254"


@app.route("/", methods=["GET", "POST"])
def index():
    url = request.form.get("url", "") if request.method == "POST" else ""
    result = ""
    if url:
        try:
            headers = {}
            host = urlparse(url).hostname or ""
            # Footgun: auto-attach the metadata header for google metadata hosts.
            if is_google_metadata(host):
                headers["Metadata-Flavor"] = "Google"
            r = requests.get(url, headers=headers, timeout=4, allow_redirects=True)
            body = r.text[:4000]
            result = f"<h3>Preview ({r.status_code})</h3><pre>{_escape(body)}</pre>"
        except Exception as e:  # noqa: BLE001
            result = f"<h3>Could not fetch</h3><pre>{_escape(str(e))}</pre>"
    return PAGE.format(url=_escape(url), result=result)


def _escape(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


@app.route("/healthz")
def healthz():
    return "ok", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
