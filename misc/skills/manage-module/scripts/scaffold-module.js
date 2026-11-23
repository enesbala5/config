#!/usr/bin/env node
// Scaffold a module workspace from this skill's templates. Never writes the router SKILL.md.
// usage:
//   node scaffold-module.js <root> <name> --scope global|local --intents make,revise,verify \
//     --layers pipeline,projects --stages brief,plan,build,qa --guide misc/guides/<topic> --purpose "..."
//   node scaffold-module.js <root> <name> --print-router [--scope global|local --intents ... --purpose ...]
// <root> is the config checkout for global scope, the working repository for local scope.
const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('scaffold-module: ' + msg); process.exit(1); }
const bt = '`';
const [rootArg, name, ...rest] = process.argv.slice(2);
if (!rootArg || !name) fail('usage: node scaffold-module.js <root> <name> [--scope global|local] [options]');
if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name)) fail('name must be lowercase kebab-case');

const opts = {};
for (let i = 0; i < rest.length; i++) {
  const flag = rest[i];
  if (!flag.startsWith('--')) continue;
  const next = rest[i + 1];
  if (next && !next.startsWith('--')) { opts[flag] = next; i++; }
  else opts[flag] = '';
}
const scope = opts['--scope'] || 'local';
if (!['global', 'local'].includes(scope)) fail('--scope must be global or local');

const expectedDir = scope === 'global' ? `misc/modules/${name}` : `misc/${name}`;
const dir = opts['--dir'] || expectedDir;
if (scope === 'global' && dir !== expectedDir) fail(`global workspace must be ${expectedDir}`);
if (dir.includes('..') || path.isAbsolute(dir)) fail('dir must be a repo-relative path without ..');

const intents = (opts['--intents'] || 'make,revise,verify,study').split(',').map((s) => s.trim()).filter(Boolean);
const layers = (opts['--layers'] || '').split(',').map((s) => s.trim()).filter(Boolean);
const stages = (opts['--stages'] || 'brief,plan,build,qa').split(',').map((s) => s.trim()).filter(Boolean);
const guideArg = (opts['--guide'] || '').trim();
const purpose = opts['--purpose'] || `work on ${name}`;
const templates = path.join(__dirname, '..', 'templates');

const rootToken = scope === 'global' ? '<config>' : '<repo>';
const workspace = `${rootToken}/${dir}/`;
const routerPath = scope === 'global'
  ? `<config>/misc/skills/${name}/SKILL.md`
  : `<repo>/.agents/skills/${name}/SKILL.md`;
const recordsPath = `<repo>/misc/${name}/`;
const guidePath = guideArg
  ? (guideArg.startsWith('misc/') ? `${rootToken}/${guideArg.replace(/\/+$/, '')}/` : guideArg)
  : '_(set the guide path when the design is approved)_';
const recordsNote = scope === 'global'
  ? `Per-project records live in ${bt}${recordsPath}${bt} in the working repository; name that path, never link across roots.`
  : `Records live in ${bt}${recordsPath}${bt}, beside the workspace.`;
const recordsRule = scope === 'global'
  ? `This shared workspace holds no per-project state. Drafts, decisions and reviews live in ${bt}${recordsPath}${bt} in the working repository, so projects from different repositories never mix. Name that path; never link across roots.`
  : `Records live in ${bt}${recordsPath}${bt}, beside the workspace. One record per target; keep the index current.`;

const intentHints = {
  make: 'new work in this domain',
  write: 'to draft new copy or copy-led content',
  revise: 'to change, polish or continue existing work',
  verify: 'to check or audit, including pre-ship checks',
  study: 'to study a reference and capture principles',
  plan: 'to plan before doing the work',
  execute: 'to carry out an approved plan',
  audit: 'to audit against the guides',
  research: 'to gather evidence before deciding',
  review: 'to review a result against the gates',
  x: 'to draft a batch of X posts',
  replies: 'to reply to a comment, post or thread',
  longform: 'to draft, outline or rewrite a long article',
  channel: 'to draft for a specific channel or platform',
};
const render = (tpl, vars) => tpl.replace(/\{\{(\w+)\}\}/g, (m, k) => (k in vars ? vars[k] : m));
const readTpl = (f) => fs.readFileSync(path.join(templates, f), 'utf8');

const intentRows = intents.map((i) =>
  `| ${intentHints[i] || `requests handled by ${i}`} | **${i}** | ${bt}${workspace}intents/${i}/README.md${bt} |`
).join('\n');
const intentList = intents.map((i) => `- **${i}** — ${bt}${workspace}intents/${i}/README.md${bt}`).join('\n');
const stageRows = stages.map((s) => `| ${s} | _(fill)_ | _(fill)_ |`).join('\n');
const layerList = layers.length
  ? layers.map((l) => `- ${l}/ — _(fill why it is needed)_`).join('\n')
  : '- _(core only; no optional layers yet)_';

const vars = {
  NAME: name, PURPOSE: purpose, SCOPE: scope, ROOT_TOKEN: rootToken,
  WORKSPACE: workspace, ROUTER_PATH: routerPath, RECORDS_PATH: recordsPath,
  RECORDS_NOTE: recordsNote, RECORDS_RULE: recordsRule,
  GUIDE_PATH: guidePath, GUIDE: guidePath, DIR: dir,
  INTENTS: intents.join(', '), INTENT_ROWS: intentRows, INTENT_LIST: intentList,
  STAGES: stages.join(', '), STAGE_ROWS: stageRows, LAYER_LIST: layerList,
  LEARNINGS_LINK: `${bt}${workspace}LEARNINGS.md${bt}`,
  PROVIDERS_LINK: `${bt}${workspace}providers/README.md${bt}`,
};

if ('--print-router' in opts) {
  process.stdout.write(render(readTpl('skill-router.md'), vars));
  process.exit(0);
}

const root = path.resolve(rootArg);
if (!fs.existsSync(root)) fail(`root not found: ${root}`);
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
write(`${dir}/providers/README.md`, render(readTpl('providers-readme.md'), vars));
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

console.log(`scope: ${scope}`);
console.log(`workspace: ${dir}`);
console.log(`created ${created.length} files in ${dir}`);
for (const f of created) console.log('  ' + f);
if (skipped.length) { console.log('skipped (already exist):'); for (const f of skipped) console.log('  ' + f); }
console.log('Router SKILL.md is intentionally not written — hand off to manage-skill.');
