#!/usr/bin/env python3
"""e02 Client Side Story — the admin control is disabled in the UI, but the SPA
bundle still references the endpoint, and the endpoint has no server-side auth."""
import os
from flask import Flask, Response, jsonify

app = Flask(__name__)
FLAG = os.environ.get("FLAG", "CYPHER{missing}")

INDEX = """<!doctype html><title>Sethsuwa Health — Patient Portal</title>
<h1>Sethsuwa Health</h1>
<p>Welcome, patient. <button disabled title="staff only">Admin Broadcast</button></p>
<script src="/static/app.9f3c1a2b.js"></script>
"""

# The front-end bundle: the disabled button's handler still knows the route.
APP_JS = """// Sethsuwa portal bundle (build 9f3c1a2b)
const API_BASE="/api";
const ROUTES={me:API_BASE+"/patient/me",
              // staff-only; button disabled for non-staff accounts
              adminBroadcast:API_BASE+"/admin/broadcast"};
async function loadMe(){return (await fetch(ROUTES.me)).json();}
async function sendBroadcast(msg){ // wired to the (disabled) Admin button
  return (await fetch(ROUTES.adminBroadcast,{method:"GET"})).json();}
"""

@app.get("/")
def index():
    return Response(INDEX, mimetype="text/html")

@app.get("/static/app.9f3c1a2b.js")
def bundle():
    return Response(APP_JS, mimetype="application/javascript")

@app.get("/api/patient/me")
def me():
    return jsonify(role="patient", name="A. Perera")

@app.get("/api/admin/broadcast")
def admin_broadcast():
    # BUG: no server-side authorisation. The UI hid this; the server does not.
    return jsonify(status="ok", motd=FLAG)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
