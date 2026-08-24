"""
LankaGov e-Services — citizen services portal (INTENTIONALLY VULNERABLE).

A fictional Sri Lankan government e-services portal for the CYPHER 4.0 tie-break.
Three chained flaws, increasing in difficulty:

  Stage 1 — Front Door   : broken access control. An "officers only" internal
                           notice board trusts a client-supplied role
                           (cookie/query param). Tampering role=officer exposes
                           FLAG1 and a staff API key.
  Stage 2 — Records Room : IDOR. With the leaked staff key, the applications API
                           returns ANY record by id with no ownership check.
                           Enumerating ids reaches a sealed record holding FLAG2
                           and a document reference.
  Stage 3 — The Vault    : path traversal. The document download endpoint joins
                           user input onto a base directory without sanitising
                           it, so `?file=../secret/vault.conf` reads the master
                           config where FLAG3 lives.

Flags are injected at container start (docker-entrypoint.sh) from run-time env,
so they never touch the image layers or this repo. FLAG3 lives only in a file on
disk, reachable via the Stage 3 traversal.
"""
import os

from flask import Flask, Response, jsonify, request

app = Flask(__name__)

FLAG1 = os.environ.get("FLAG1", "CYPHER{stage1_placeholder}")
FLAG2 = os.environ.get("FLAG2", "CYPHER{stage2_placeholder}")
# FLAG3 is NOT read here — it lives in secret/vault.conf and is only reachable
# through the Stage 3 path-traversal bug.
DOCS_DIR = os.environ.get("DOCS_DIR", "/srv/lankagov/documents")
# Shared across gunicorn workers because docker-entrypoint.sh exports it before
# exec'ing gunicorn — otherwise each worker would mint a different key and the
# Stage 1 -> Stage 2 chain would break intermittently.
STAFF_KEY = os.environ.get("STAFF_KEY", "devkey0000000000")

# Citizen-visible + sealed application records. The IDOR is that Stage 2 serves
# any of these by id with no ownership check.
APPLICATIONS = {
    1001: {
        "applicant": "A. Common (you)",
        "nic": "9x-xxxx-citizen",
        "service": "Driving permit renewal",
        "district": "Colombo",
        "status": "approved",
    },
    1002: {
        "applicant": "S. Perera",
        "nic": "8x-xxxx-redacted",
        "service": "Birth certificate copy",
        "district": "Gampaha",
        "status": "processing",
    },
    1050: {
        "applicant": "K. Fernando",
        "nic": "7x-xxxx-redacted",
        "service": "Business registration",
        "district": "Kandy",
        "status": "approved",
    },
    4471: {
        "applicant": "[SEALED — RESTRICTED CLEARANCE]",
        "nic": "[SEALED]",
        "service": "Firearm license (RESTRICTED)",
        "district": "[SEALED]",
        "status": "approved",
        "internal_note": FLAG2,  # Stage 2 objective: FLAG2 lives in this sealed record
        "document": "sealed_4471.pdf",
        "remarks": "Full case file in Records document store. Officers may "
                   "download via /api/documents?file=sealed_4471.pdf",
    },
}


LANDING = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LankaGov e-Services</title>
<style>
 body{{font-family:system-ui,Segoe UI,Roboto,sans-serif;max-width:820px;margin:2rem auto;
 padding:0 1rem;background:#0d1117;color:#e6edf3;line-height:1.55}}
 header{{border-bottom:2px solid #1f6feb;padding-bottom:.6rem;margin-bottom:1rem}}
 .gov{{color:#f0a500;font-weight:700;letter-spacing:.5px}}
 a{{color:#58a6ff}} code{{background:#161b22;padding:.1rem .35rem;border-radius:4px}}
 .card{{background:#161b22;border:1px solid #30363d;border-radius:10px;padding:1rem;margin:.8rem 0}}
 .muted{{color:#8b949e;font-size:.9rem}}
</style></head><body>
<header>
  <div class="gov">🇱🇰 LankaGov e-Services</div>
  <div class="muted">Government of the Democratic Socialist Republic — Citizen Services Portal</div>
</header>

<p>Welcome, citizen. Track your applications and download issued documents.</p>

<div class="card">
  <h3>Your applications</h3>
  <p>You are signed in as <b>A. Common</b>. Your active application:
     <a href="/api/applications/1001">#1001 — Driving permit renewal</a>.</p>
  <p class="muted">Applications are served by our records API at
     <code>/api/applications/&lt;id&gt;</code>.</p>
</div>

<div class="card">
  <h3>Services</h3>
  <ul>
    <li>Driving permits &amp; renewals</li>
    <li>Civil registration (birth / marriage certificates)</li>
    <li>Business registration</li>
    <li>Document download centre — <code>/api/documents?file=&lt;name&gt;</code></li>
  </ul>
</div>

<!-- OFFICERS: the internal notice board moved under /api/internal/ during the
     2026 portal refresh. Access is role-restricted. -->

<p class="muted">Portal v3.2 · For assistance contact your divisional secretariat.</p>
</body></html>"""


@app.route("/")
def index():
    return Response(LANDING, mimetype="text/html")


@app.route("/robots.txt")
def robots():
    # Recon breadcrumb toward Stage 1.
    return Response(
        "User-agent: *\nDisallow: /api/internal/\nDisallow: /api/documents\n",
        mimetype="text/plain",
    )


# ---- Stage 1: broken access control -----------------------------------------
@app.route("/api/internal/notices")
def internal_notices():
    # VULN: trusts a client-supplied role. No server-side authorisation.
    role = request.args.get("role") or request.cookies.get("role") or "citizen"
    if role != "officer":
        return (
            jsonify(
                error="Officers only.",
                your_role=role,
                hint="This board is for role=officer.",
            ),
            403,
        )
    return jsonify(
        notices=[
            {"id": 1, "title": "Scheduled maintenance",
             "body": "Records API maintenance window Sunday 0200-0400."},
            {"id": 2, "title": "Staff API key (rotated)",
             "body": f"Current staff key for the records API: {STAFF_KEY}"},
            {"id": 3, "title": "Security marker",
             "body": f"Internal audit marker: {FLAG1}"},
        ]
    )


# ---- Stage 2: IDOR ----------------------------------------------------------
@app.route("/api/applications/<int:app_id>")
def get_application(app_id):
    # The staff key (leaked in Stage 1) gates the records API...
    if request.headers.get("X-Staff-Key") != STAFF_KEY:
        return (
            jsonify(error="missing or invalid X-Staff-Key header",
                    hint="Officers authenticate to the records API with a staff key."),
            401,
        )
    # ...but there is NO ownership check: any id is returned. That is the IDOR.
    rec = APPLICATIONS.get(app_id)
    if not rec:
        return jsonify(error=f"no application #{app_id}"), 404
    return jsonify(application=rec)


# ---- Stage 3: path traversal ------------------------------------------------
@app.route("/api/documents")
def documents():
    if request.headers.get("X-Staff-Key") != STAFF_KEY:
        return (
            jsonify(error="missing or invalid X-Staff-Key header"),
            401,
        )
    name = request.args.get("file", "")
    if not name:
        return jsonify(error="file parameter required",
                       example="/api/documents?file=sealed_4471.pdf"), 400
    # VULN (intended): user input joined onto the base dir with no containment
    # check, so ../ escapes DOCS_DIR (e.g. ../secret/vault.conf). This traversal
    # is the Stage 3 objective and is deliberately preserved.
    path = os.path.join(DOCS_DIR, name)
    # Availability guards ONLY (do not narrow the traversal): reject anything
    # that isn't a plain regular file, and cap the read. Without these, pointing
    # ?file= at a device (/dev/random), a FIFO, a directory, or a huge file
    # blocks a worker for the whole request timeout — which is what took the
    # service down. vault.conf is a small regular file, so the solve is unaffected.
    MAX_BYTES = 256 * 1024
    if not os.path.isfile(path):
        return jsonify(error=f"cannot read document: {name}"), 404
    try:
        if os.path.getsize(path) > MAX_BYTES:
            return jsonify(error="document too large"), 413
        with open(path, "rb") as fh:
            data = fh.read(MAX_BYTES)
        return Response(data, mimetype="application/octet-stream")
    except (FileNotFoundError, IsADirectoryError, PermissionError, OSError):
        return jsonify(error=f"cannot read document: {name}"), 404


@app.route("/healthz")
def healthz():
    return jsonify(ok=True)
