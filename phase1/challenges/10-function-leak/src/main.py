"""
Ruhunu Bank — "Greeting" Cloud Function.

Renders a customisable greeting. The template is taken straight from user input
and passed to str.format() with the environment exposed as a field — a classic
Python format-string injection that leaks environment variables (including the
flag) when the caller supplies `template={env}`.
"""
import os

import functions_framework


@functions_framework.http
def handler(request):
    name = request.args.get("name", "customer")
    template = request.args.get("template", "Hello, {name}! Welcome to Ruhunu Bank.")
    try:
        # Vulnerability: user-controlled format string + env exposed as a field.
        body = template.format(name=name, env=dict(os.environ))
    except Exception as e:  # noqa: BLE001
        body = f"template error: {e}"
    return (body, 200, {"Content-Type": "text/plain; charset=utf-8"})
