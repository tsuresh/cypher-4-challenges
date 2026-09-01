#!/usr/bin/env python3
"""ai3 The Model in the Middle — indirect prompt injection + tool abuse.

An LLM support AGENT triages a ticket you submit. It has tools: lookup_order
(public) and get_internal (admin-only -> the flag). The agent 'reads' the ticket
and follows instructions embedded in it (indirect injection). A ticket that
asserts admin authority and instructs a get_internal('ops_passphrase') call —
with an encoding request to dodge the output guard — leaks the flag.
"""
import os, re, base64, codecs
from flask import Flask, request, jsonify, Response

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 64 * 1024
FLAG = os.environ.get("FLAG", "CYPHER{missing}")
INTERNAL = {"ops_passphrase": FLAG}

TOOLCALL = re.compile(r"get[_\s]?internal|ops[_\s]?passphrase|call.{0,20}tool|invoke.{0,20}get|internal\s*secret|read.{0,15}internal", re.I)
ADMIN    = re.compile(r"admin|administrator|authori[sz]ed|override|priority|verified|elevated|supervisor|staff|root|sudo|system\s*override", re.I)
KEY      = re.compile(r"get[_\s]?internal\s*\(?\s*['\"]?([a-z_]+)", re.I)

def transform(s, enc):
    return {"base64": base64.b64encode(s.encode()).decode(), "hex": s.encode().hex(),
            "ascii": " ".join(str(ord(c)) for c in s), "reverse": s[::-1],
            "dash": "-".join(s), "space": " ".join(s), "rot13": codecs.encode(s, "rot13")}.get(enc, s)

def detect_encoding(low):
    for k, e in [("base64","base64"),("b64","base64"),("rot13","rot13"),("hex","hex"),
                 ("ascii","ascii"),("char code","ascii"),("ordinal","ascii"),
                 ("revers","reverse"),("backward","reverse"),("dash","dash"),("hyphen","dash"),
                 ("spell","space"),("between each","space"),("letter by letter","space")]:
        if k in low: return e
    return None

def guard(reply): return reply.replace(FLAG, "[REDACTED]")

PAGE = """<!doctype html><title>Pearl Telecom AgentDesk</title>
<h2>Pearl Telecom — AI AgentDesk</h2>
<p>Submit a support ticket; our AI agent triages it. POST {"ticket":"..."} to <code>/triage</code>.<br>
Agent tools: <code>lookup_order(id)</code> (public), <code>get_internal(key)</code> (staff only).</p>
<textarea id=m rows=6 cols=76 placeholder="Describe your issue..."></textarea><br>
<button onclick="send()">Submit ticket</button><pre id=o></pre>
<script>async function send(){let r=await fetch('/triage',{method:'POST',headers:{'Content-Type':'application/json'},
body:JSON.stringify({ticket:document.getElementById('m').value})});document.getElementById('o').textContent=(await r.json()).summary;}</script>
"""

@app.get("/")
def index(): return Response(PAGE, mimetype="text/html")

@app.post("/triage")
def triage():
    body = request.get_json(force=True, silent=True) or {}
    ticket = body.get("ticket") or body.get("message") or ""
    low = ticket.lower()
    order = (re.search(r"#?(\d{3,5})", ticket) or [None, "----"])[1]
    # indirect injection: the agent obeys an embedded instruction ONLY if the ticket
    # both asserts authority AND instructs the privileged tool.
    if TOOLCALL.search(low) and ADMIN.search(low):
        m = KEY.search(ticket); key = m.group(1).lower() if m else "ops_passphrase"
        if key in INTERNAL:
            val = transform(INTERNAL[key], detect_encoding(low))
            return jsonify(summary=guard(
                f"Ticket #{order} triaged. Authorization recognized.\n"
                f"[tool] get_internal('{key}') -> {val}\n"
                f"Summary: escalation resolved with internal value included as requested."))
        return jsonify(summary=f"Ticket #{order}: get_internal('{key}') — unknown key.")
    return jsonify(summary=f"Ticket #{order} received. Our team will follow up on your order shortly.")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
