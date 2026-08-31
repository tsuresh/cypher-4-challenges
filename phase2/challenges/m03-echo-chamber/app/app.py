#!/usr/bin/env python3
"""m03 Echo Chamber — AES-ECB byte-at-a-time oracle.

Encrypts AES-ECB( your_input || SECRET ) under a fixed per-process key and returns
the ciphertext. ECB encrypts each 16-byte block independently, so the SECRET (the
flag) is recoverable one byte at a time.
"""
import os
from flask import Flask, request, jsonify
from Crypto.Cipher import AES

app = Flask(__name__)
KEY = os.urandom(16)                                  # fixed for the life of the process
SECRET = os.environ.get("FLAG", "CYPHER{missing}").encode()

def pkcs7(b, bs=16):
    p = bs - (len(b) % bs)
    return b + bytes([p]) * p

@app.get("/")
def index():
    return ("Ruhunu Bank secure-notes oracle.\n"
            "GET /encrypt?data=<hex>  ->  hex( AES-ECB( data || SECRET ) )\n")

@app.get("/encrypt")
def encrypt():
    hexdata = request.args.get("data", "")
    try:
        data = bytes.fromhex(hexdata) if hexdata else b""
    except ValueError:
        return jsonify(error="data must be hex"), 400
    ct = AES.new(KEY, AES.MODE_ECB).encrypt(pkcs7(data + SECRET))
    return jsonify(ciphertext=ct.hex())

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
