#!/usr/bin/env node
// Read-only integrity check for a generated module.
// usage: node verify-module.js <repo> <name>
const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('verify-module: ' + msg); process.exit(1); }
const [repoArg, name] = process.argv.slice(2);
if (!repoArg || !name) fail('usage: node verify-module.js <repo> <name>');
const repo = path.resolve(repoArg);
const base = path.join(repo, 'misc', name);
const router = path.join(repo, '.agents', 'skills', name, 'SKILL.md');
if (!fs.existsSync(base)) fail(`missing workspace: ${base}`);

const problems = [];
const required = ['AGENTS.md', 'README.md', 'LEARNINGS.md'];
for (const f of required) if (!fs.existsSync(path.join(base, f))) problems.push(`missing ${f}`);
const intentsDir = path.join(base, 'intents');
if (!fs.existsSync(intentsDir)) problems.push('missing intents/');
else {
  const intents = fs.readdirSync(intentsDir, { withFileTypes: true })
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
  for (const m of text.matchAll(/intents\/([^/`]+)\/README\.md/g)) {
    if (!fs.existsSync(path.join(intentsDir, m[1], 'README.md'))) problems.push(`router: unknown intent ${m[1]}`);
  }
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
  const rel = path.relative(repo, file);
  if (/\/home\/|\/tmp\/|~\//.test(text)) problems.push(`${rel}: absolute or home-relative path`);
  if (/misc\/(video|design)\//.test(text)) problems.push(`${rel}: points at another module's workspace`);
  if (/\{\{[A-Z_]+\}\}/.test(text)) problems.push(`${rel}: unrendered template token`);
  for (const m of text.matchAll(/\]\(([^)]+)\)/g)) {
    const target = m[1].split('#')[0];
    if (!target || /^(https?:|mailto:)/.test(target)) continue;
    if (!fs.existsSync(path.resolve(path.dirname(file), target))) problems.push(`${rel}: dead link ${target}`);
  }
}

console.log(`workspace: ${path.relative(repo, base)}`);
if (problems.length) { console.log('PROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('OK');
