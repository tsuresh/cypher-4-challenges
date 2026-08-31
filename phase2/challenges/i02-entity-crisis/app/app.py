#!/usr/bin/env python3
"""i02 Entity Crisis — an XML form endpoint that parses user XML with external
entities enabled (XXE). The parsed <nic> value is echoed back, so file:// entities
are reflected. Flag lives at /flag on the container filesystem."""
import os
from flask import Flask, request, Response
from lxml import etree

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 64 * 1024      # cap body size (large-doc DoS)

@app.get("/")
def index():
    return Response(
        "LankaGov e-Forms gateway. POST XML to /api/forms/submit\n"
        "Expected: <form><nic>...</nic><reason>...</reason></form>\n",
        mimetype="text/plain")

@app.post("/api/forms/submit")
def submit():
    raw = request.get_data()
    try:
        # BUG (intended): external entities + DTD loading enabled -> XXE; file://
        # still resolves. huge_tree stays OFF so lxml's entity-expansion limit blocks
        # billion-laughs / exponential-expansion DoS, and no_network blocks SSRF via
        # external DTDs. The simple file-read XXE the challenge needs is unaffected.
        parser = etree.XMLParser(resolve_entities=True, load_dtd=True,
                                 no_network=True, huge_tree=False)
        root = etree.fromstring(raw, parser)
    except Exception as e:
        return Response(f"parse error: {e}\n", status=400, mimetype="text/plain")
    nic = root.findtext("nic") or ""
    reason = root.findtext("reason") or ""
    return Response(f"Application received.\n  NIC: {nic}\n  Reason: {reason}\n",
                    mimetype="text/plain")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
