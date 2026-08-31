#!/usr/bin/env python3
"""h06 Render Unto Ceylon — Jinja2 SSTI behind a naive denylist WAF.

The invoice previewer renders user-supplied template text. A denylist blocks the
obvious payload words, so the solve needs attribute indirection (|attr with
hex-escaped dunders) and string building to reach an os.popen gadget and read /flag.
"""
import os
from flask import Flask, request, render_template_string, Response

app = Flask(__name__)

# Naive substring denylist (case-insensitive). This is the intended-bypassable WAF.
BLOCK = ["__class__", "__globals__", "__mro__", "__subclasses__", "__init__",
         "__builtins__", "os.", "popen", "system", "subprocess", "import",
         "eval(", "exec(", "request", "config", ".read(", "flag", "|attr(\"os", "'os'"]

def waf(s: str) -> bool:
    low = s.lower()
    return any(b in low for b in BLOCK)

@app.get("/")
def index():
    return Response("Ceylon Kade invoice previewer.\n"
                    "POST form field 'template' to /preview to render your invoice.\n",
                    mimetype="text/plain")

@app.post("/preview")
def preview():
    tpl = request.form.get("template", "")
    if waf(tpl):
        return Response("Blocked by template firewall.\n", status=403, mimetype="text/plain")
    try:
        out = render_template_string("Invoice preview:\n" + tpl)
    except Exception as e:
        return Response(f"render error: {e}\n", status=500, mimetype="text/plain")
    return Response(out + "\n", mimetype="text/plain")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
