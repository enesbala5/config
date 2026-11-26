#!/usr/bin/env node
// Read-only integrity check for a generated module.
// usage: node verify-module.js <root> <name> --scope global|local
const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('verify-module: ' + msg); process.exit(1); }
const args = process.argv.slice(2);
const [rootArg, name] = args;
if (!rootArg || !name) fail('usage: node verify-module.js <root> <name> --scope global|local');
const opts = {};
for (let i = 2; i < args.length; i++) {
  const flag = args[i];
  if (!flag.startsWith('--')) continue;
  const next = args[i + 1];
  if (next && !next.startsWith('--')) { opts[flag] = next; i++; }
  else opts[flag] = '';
}
const scope = opts['--scope'] || 'local';
if (!['global', 'local'].includes(scope)) fail('--scope must be global or local');

const root = path.resolve(rootArg);
const dir = scope === 'global' ? path.join('misc', 'modules', name) : path.join('misc', name);
const base = path.join(root, dir);
const router = scope === 'global'
  ? path.join(root, 'misc', 'skills', name, 'SKILL.md')
  : path.join(root, '.agents', 'skills', name, 'SKILL.md');
const ownToken = scope === 'global' ? '<config>' : '<repo>';
if (!fs.existsSync(base)) fail(`missing workspace: ${base}`);

const problems = [];
const required = ['AGENTS.md', 'README.md', 'LEARNINGS.md', 'CONSUMED-LESSONS.yml', 'providers/README.md'];
for (const f of required) if (!fs.existsSync(path.join(base, f))) problems.push(`missing ${f}`);
const consumedPath = path.join(base, 'CONSUMED-LESSONS.yml');
if (fs.existsSync(consumedPath)) {
  const consumed = fs.readFileSync(consumedPath, 'utf8');
  if (!/^version:\s*1\s*$/m.test(consumed)) problems.push('CONSUMED-LESSONS.yml: missing version: 1');
  const entriesAt = consumed.indexOf('entries:');
  if (entriesAt < 0) problems.push('CONSUMED-LESSONS.yml: missing entries:');
  else {
    const body = consumed.slice(entriesAt + 'entries:'.length).split(/\r?\n/).filter((line) => line.trim() && !line.trim().startsWith('#'));
    const entryMatches = [...consumed.matchAll(/^  - lesson: (.+)\r?\n    consumed_on: (\d{4}-\d{2}-\d{2})$/gm)];
    const matchedLines = entryMatches.reduce((count) => count + 2, 0);
    if (!(body.length === 1 && body[0].trim() === '[]') && (body.length !== matchedLines || !entryMatches.length)) {
      problems.push('CONSUMED-LESSONS.yml: entries must use `  - lesson: <repo-relative-path>` followed by `    consumed_on: YYYY-MM-DD`; use `entries: []` when empty');
    }
    for (const [, lesson, date] of entryMatches) {
      if (path.isAbsolute(lesson) || lesson.split(/[\\/]/).includes('..') || lesson.startsWith('~')) problems.push(`CONSUMED-LESSONS.yml: lesson path must be repository-relative and stay in root: ${lesson}`);
      const parsed = new Date(`${date}T00:00:00Z`);
      if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== date) problems.push(`CONSUMED-LESSONS.yml: invalid consumed_on date: ${date}`);
    }
  }
}
const intentsDir = path.join(base, 'intents');
let intents = [];
if (!fs.existsSync(intentsDir)) problems.push('missing intents/');
else {
  intents = fs.readdirSync(intentsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(intentsDir, d.name, 'README.md')))
    .map((d) => d.name);
  if (!intents.length) problems.push('no intent has a README.md');
}

if (!fs.existsSync(router)) problems.push('router SKILL.md missing (manage-skill handoff pending?)');
else {
  const text = fs.readFileSync(router, 'utf8');
  const fm = text.match(/^---\n([\s\S]*?)\n---/);
  if (!fm) problems.push('router: invalid frontmatter');
  else {
    const nm = fm[1].match(/^name:\s*(.+)$/m);
    if (!nm || nm[1].trim() !== name) problems.push(`router: name does not match folder (expected ${name})`);
    const desc = fm[1].match(/^description:\s*.+/m);
    if (!desc) problems.push('router: missing description');
  }
  const rows = new Set();
  for (const m of text.matchAll(/intents\/([^/`]+)\/README\.md/g)) {
    rows.add(m[1]);
    if (!fs.existsSync(path.join(intentsDir, m[1], 'README.md'))) problems.push(`router: unknown intent ${m[1]}`);
  }
  for (const intent of intents) if (!rows.has(intent)) problems.push(`router: missing row for intent ${intent}`);
}

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else if (entry.name.endsWith('.md')) out.push(p);
  }
  return out;
}
for (const file of walk(base)) {
  const text = fs.readFileSync(file, 'utf8');
  const rel = path.relative(root, file);
  if (/\/home\/|\/tmp\/|~\//.test(text)) problems.push(`${rel}: absolute or home-relative path`);
  for (const m of text.matchAll(/misc\/(video|design)\//g)) {
    if (m[0] === `misc/${name}/`) continue;
    problems.push(`${rel}: points at another module's workspace`);
    break;
  }
  if (/\{\{[A-Z_]+\}\}/.test(text)) problems.push(`${rel}: unrendered template token`);
  for (const m of text.matchAll(/\]\(([^)]+)\)/g)) {
    const target = m[1].split('#')[0];
    if (!target || /^(https?:|mailto:)/.test(target)) continue;
    const resolved = path.resolve(path.dirname(file), target);
    if (resolved !== root && !resolved.startsWith(root + path.sep)) {
      problems.push(`${rel}: link escapes the ${scope} root: ${target}`);
    }
    if (!fs.existsSync(resolved)) problems.push(`${rel}: dead link ${target}`);
  }
  for (const m of text.matchAll(/`(<config>|<repo>)\/([^`]+)`/g)) {
    if (m[1] !== ownToken || m[2].includes('<')) continue;
    if (!fs.existsSync(path.join(root, m[2]))) problems.push(`${rel}: missing ${m[1]}/${m[2]}`);
  }
}

try {
  const realRoot = fs.realpathSync(root);
  for (const [label, target] of [['workspace', base], ['router', router]]) {
    if (!fs.existsSync(target)) continue;
    const real = fs.realpathSync(target);
    if (real !== realRoot && !real.startsWith(realRoot + path.sep)) {
      problems.push(`${label} resolves outside the ${scope} root (symlinked install?)`);
    }
  }
} catch (e) {
  problems.push('cannot resolve real paths: ' + e.message);
}

console.log(`scope: ${scope}`);
console.log(`workspace: ${path.relative(root, base)}`);
if (problems.length) { console.log('PROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('OK');
