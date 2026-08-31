#!/usr/bin/env python3
"""h10 Once Is Enough — AES-GCM oracle that reuses a FIXED nonce (the vuln).

  GET  /encrypt?data=<hex>   -> encrypts (data padded/truncated to 16 bytes),
                                returns {nonce, ct, tag} (empty AAD, fixed nonce)
  POST /submit {nonce,ct,tag}-> verifies the tag with the real key; if valid AND the
                                plaintext contains 'admin', returns the flag.

Two ciphertexts under the reused nonce leak the GHASH key H (forbidden attack),
letting the player forge a valid tag for a role=admin message.
"""
import os, json
from flask import Flask, request, jsonify
import gcm

app = Flask(__name__)
KEY = os.urandom(16)
NONCE = os.urandom(12)                 # FIXED for the process — reused on every call
FLAG = os.environ.get("FLAG", "CYPHER{missing}")

@app.get("/")
def index():
    return ("Sethsuwa secure-notes.\n"
            "GET /encrypt?data=<hex>  |  POST /submit {nonce,ct,tag}\n")

@app.get("/encrypt")
def encrypt():
    try:
        data = bytes.fromhex(request.args.get("data", ""))
    except ValueError:
        return jsonify(error="hex please"), 400
    block = (data + b"\x00" * 16)[:16]          # exactly one 16-byte block
    ct, tag = gcm.gcm_encrypt(KEY, NONCE, block)
    return jsonify(nonce=NONCE.hex(), ct=ct.hex(), tag=tag.hex())

@app.post("/submit")
def submit():
    j = request.get_json(force=True, silent=True) or {}
    try:
        nonce = bytes.fromhex(j["nonce"]); ct = bytes.fromhex(j["ct"]); tag = bytes.fromhex(j["tag"])
        pt = gcm.gcm_decrypt(KEY, nonce, ct, tag)     # raises on bad tag
    except Exception as e:
        return jsonify(error=f"rejected: {e}"), 403
    if b"admin" in pt:
        return jsonify(status="authenticated", flag=FLAG)
    return jsonify(status="ok", note="valid tag, but not admin"), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
