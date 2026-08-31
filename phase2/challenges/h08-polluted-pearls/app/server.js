// h08 Polluted Pearls — prototype pollution -> RCE.
// /api/preferences deep-merges user JSON into config WITHOUT guarding __proto__.
// /api/render later reads an option off a fresh object; if Object.prototype was
// polluted with `cmd`, that option is attacker-controlled and reaches execSync.
const express = require('express');
const { execSync } = require('child_process');

const app = express();
app.use(express.json());

const config = { theme: 'default', locale: 'si-LK' };

// Vulnerable recursive merge (no __proto__ / constructor guard).
function merge(target, source) {
  for (const k in source) {
    if (k in target && typeof target[k] === 'object' && target[k] !== null &&
        typeof source[k] === 'object' && source[k] !== null) {
      merge(target[k], source[k]);
    } else {
      target[k] = source[k];
    }
  }
  return target;
}

app.get('/', (_req, res) =>
  res.type('text/plain').send(
    'Pearl Telecom dashboard.\n' +
    'POST /api/preferences  {json}   -> saves preferences (deep-merged)\n' +
    'GET  /api/render                -> renders your dashboard report\n'));

app.post('/api/preferences', (req, res) => {
  try {
    merge(config, req.body || {});
    res.json({ status: 'saved', config });
  } catch (e) {
    res.status(400).json({ error: String(e) });
  }
});

// Sink on a DIFFERENT route: builds a report using an option it never set itself.
app.get('/api/render', (_req, res) => {
  const opts = {};                                  // inherits from (maybe polluted) proto
  const cmd = opts.cmd || 'echo "no report configured"';
  let out;
  try { out = execSync(cmd, { timeout: 4000 }).toString(); }
  catch (e) { out = 'render failed: ' + String(e); }
  res.type('text/plain').send('Dashboard report:\n' + out);
});

app.listen(process.env.PORT || 8000, () =>
  console.log('h08 listening on ' + (process.env.PORT || 8000)));
