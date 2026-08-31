# e02 — Client Side Story (Sethsuwa Health)

**Category:** Web / Client-side secret · **Difficulty:** Easy · **Points:** 200 (dynamic)

## Intended solve
```sh
# The patient portal is a single-page app. The "Admin" button is greyed out in the UI,
# but the front-end code still knows the endpoint it would call.
curl -s http://<vm-ip>:PORT/static/app.<hash>.js | grep -Eo '/api/[a-z/_-]+'
#   -> reveals a hidden route, e.g. /api/admin/broadcast
curl -s http://<vm-ip>:PORT/api/admin/broadcast          # server never checks role -> CYPHER{...}
```
The gate is **client-side only**: the disabled button hides the feature in the browser, but the
backend route is unauthenticated. Read the bundle, call the route directly.

## Infra & safety
- Small static SPA + a thin API (per-team instance via ctfd-whale). The flag is returned by the
  hidden endpoint; it is **not** present in the JS bundle itself (only the path is).
- Per-team container so each team gets its own instance and flag.

## Remediation (Blue Team Brief)
Authorisation must be enforced server-side; hiding a control in the client is not access control.
Never assume an endpoint is safe because the UI doesn't link it. Treat every route as reachable.
