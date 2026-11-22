#!/usr/bin/env node
// Scaffold a module workspace from this skill's templates. Never writes the router SKILL.md.
// usage:
//   node scaffold-module.js <repo> <name> --dir misc/<name> --intents make,revise,verify,study \
//     --layers pipeline,projects --stages brief,plan,build,qa --guide misc/guides/<topic> --purpose "..."
//   node scaffold-module.js <repo> <name> --print-router [--intents ... --dir ... --purpose ...]
const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('scaffold-module: ' + msg); process.exit(1); }
const [repo, name, ...rest] = process.argv.slice(2);
if (!repo || !name) fail('usage: node scaffold-module.js <repo> <name> [options]');
if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name)) fail('name must be lowercase kebab-case');

const opts = {};
for (let i = 0; i < rest.length; i++) {
  const flag = rest[i];
  if (!flag.startsWith('--')) continue;
  const next = rest[i + 1];
  if (next && !next.startsWith('--')) { opts[flag] = next; i++; }
  else opts[flag] = '';
}
const dir = opts['--dir'] || `misc/${name}`;
const intents = (opts['--intents'] || 'make,revise,verify,study').split(',').map((s) => s.trim()).filter(Boolean);
const layers = (opts['--layers'] || '').split(',').map((s) => s.trim()).filter(Boolean);
const stages = (opts['--stages'] || 'brief,plan,build,qa').split(',').map((s) => s.trim()).filter(Boolean);
const guide = opts['--guide'] || '_(set the guide path when the design is approved)_';
const purpose = opts['--purpose'] || `work on ${name}`;
const templates = path.join(__dirname, '..', 'templates');

const intentHints = {
  make: 'new work in this domain',
  revise: 'to change or continue existing work',
  verify: 'to check or audit, including pre-ship checks',
  study: 'to study a reference and capture principles',
  plan: 'to plan before doing the work',
  execute: 'to carry out an approved plan',
  audit: 'to audit against the guides',
  research: 'to gather evidence before deciding',
  review: 'to review a result against the gates',
};
const render = (tpl, vars) => tpl.replace(/\{\{(\w+)\}\}/g, (m, k) => (k in vars ? vars[k] : m));
const readTpl = (f) => fs.readFileSync(path.join(templates, f), 'utf8');

const intentRows = intents.map((i) =>
  `| ${intentHints[i] || `requests handled by ${i}`} | **${i}** | \`${dir}/intents/${i}/README.md\` |`
).join('\n');
const intentList = intents.map((i) => `- **${i}** — [intents/${i}/README.md](intents/${i}/README.md)`).join('\n');
const stageRows = stages.map((s) => `| ${s} | _(fill)_ | _(fill)_ |`).join('\n');
const layerList = layers.length
  ? layers.map((l) => `- ${l}/ — _(fill why it is needed)_`).join('\n')
  : '- _(core only; no optional layers yet)_';

const vars = {
  NAME: name, PURPOSE: purpose, GUIDE: guide, DIR: dir,
  INTENTS: intents.join(', '), INTENT_ROWS: intentRows, INTENT_LIST: intentList,
  STAGES: stages.join(', '), STAGE_ROWS: stageRows, LAYER_LIST: layerList,
  LEARNINGS_LINK: '[LEARNINGS.md](LEARNINGS.md)',
};

if ('--print-router' in opts) {
  process.stdout.write(render(readTpl('skill-router.md'), vars));
  process.exit(0);
}

const root = path.resolve(repo);
if (!fs.existsSync(root)) fail(`repo not found: ${root}`);
const base = path.join(root, dir);
const created = [], skipped = [];
function write(rel, content) {
  const target = path.join(root, rel);
  if (fs.existsSync(target)) { skipped.push(rel); return; }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content);
  created.push(rel);
}

write(`${dir}/AGENTS.md`, render(readTpl('workspace-agents.md'), vars));
write(`${dir}/README.md`, render(readTpl('workspace-readme.md'), vars));
write(`${dir}/LEARNINGS.md`, render(readTpl('learnings.md'), vars));
for (const intent of intents) {
  write(`${dir}/intents/${intent}/README.md`, render(readTpl('intent-readme.md'), { ...vars, INTENT: intent }));
}
if (layers.includes('pipeline')) {
  write(`${dir}/pipeline/README.md`, render(readTpl('pipeline-readme.md'), vars));
  for (const stage of stages) write(`${dir}/pipeline/${stage}/README.md`, render(readTpl('stage-readme.md'), { ...vars, STAGE: stage }));
}
if (layers.includes('projects')) {
  write(`${dir}/projects/README.md`, render(readTpl('projects-readme.md'), vars));
  write(`${dir}/PROJECTS.md`, `# ${name} records index\n\n_One status, one-line purpose, path only when it overrides the default._\n`);
}
if (layers.includes('references')) write(`${dir}/references/README.md`, render(readTpl('references-readme.md'), vars));
if (layers.includes('rules')) write(`${dir}/rules/README.md`, render(readTpl('rules-readme.md'), vars));

console.log(`created ${created.length} files in ${dir}`);
for (const f of created) console.log('  ' + f);
if (skipped.length) { console.log('skipped (already exist):'); for (const f of skipped) console.log('  ' + f); }
console.log('Router SKILL.md is intentionally not written — hand off to manage-skill.');
