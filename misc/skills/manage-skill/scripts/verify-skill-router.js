#!/usr/bin/env node
// Read-only integrity check for a thin-router skill.
// usage: node verify-skill-router.js [skill-dir]   (default: this skill's folder)
const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('verify-skill-router: ' + msg); process.exit(1); }
const skillDir = path.resolve(process.argv[2] || path.join(__dirname, '..'));
const skillName = path.basename(skillDir);
const router = path.join(skillDir, 'SKILL.md');
const intentsDir = path.join(skillDir, 'intents');
const rules = path.join(intentsDir, 'rules.md');
if (!fs.existsSync(router)) fail(`missing router: ${router}`);

const problems = [];

// Required files: router, single shared rules file, this verifier.
for (const f of [router, rules, path.join(skillDir, 'scripts', 'verify-skill-router.js')]) {
  if (!fs.existsSync(f)) problems.push(`missing ${path.relative(skillDir, f)}`);
}

// Router frontmatter.
const text = fs.readFileSync(router, 'utf8');
const fm = text.match(/^---\n([\s\S]*?)\n---/);
if (!fm) problems.push('router: invalid frontmatter');
else {
  const nm = fm[1].match(/^name:\s*(.+)$/m);
  if (!nm || nm[1].trim() !== skillName) problems.push(`router: name does not match folder (expected ${skillName})`);
  const desc = fm[1].match(/^description:\s*.+/m);
  if (!desc) problems.push('router: missing description');
}

// Router rows vs intent folders (both directions). An intent is a folder with
// a README.md; files directly under intents/ (rules.md) are not intents.
const dirs = fs.existsSync(intentsDir)
  ? fs.readdirSync(intentsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && !d.name.startsWith('_') && fs.existsSync(path.join(intentsDir, d.name, 'README.md')))
      .map((d) => d.name).sort()
  : [];
if (!dirs.length) problems.push('no intent folder has a README.md');

const rows = [...text.matchAll(/intents\/([^/`\s)]+)\/README\.md/g)].map((m) => m[1]);
for (const name of new Set(rows)) {
  if (!dirs.includes(name)) problems.push(`router: unknown intent ${name}`);
}
for (const name of dirs) {
  if (!rows.includes(name)) problems.push(`router: missing row for intent ${name}`);
}

// Every intent loads the read-chain root; it never restates the shared rules.
for (const name of dirs) {
  const intentText = fs.readFileSync(path.join(intentsDir, name, 'README.md'), 'utf8');
  if (!/\.\.\/rules\.md/.test(intentText)) {
    problems.push(`intents/${name}/README.md: missing read-chain link to ../rules.md`);
  }
}

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else if (entry.name.endsWith('.md')) out.push(p);
  }
  return out;
}

// Links stay in this skill; no absolute/home-relative paths or template tokens.
// The two documented config-checkout locations are allowed.
for (const file of walk(skillDir)) {
  const t = fs.readFileSync(file, 'utf8');
  const rel = path.relative(skillDir, file);
  const portable = t.replace(/~?\/\.agents\/skills/g, '<CONFIG>').replace(/~?\/config/g, '<CONFIG>');
  if (/\/home\/|\/tmp\/|~\//.test(portable)) problems.push(`${rel}: absolute or home-relative path`);
  if (/\{\{[A-Z_]+\}\}/.test(t)) problems.push(`${rel}: unrendered template token`);
  for (const m of t.matchAll(/\]\(([^)]+)\)/g)) {
    const target = m[1].split('#')[0].trim();
    if (!target || /^(https?:|mailto:)/.test(target)) continue;
    const resolved = path.resolve(path.dirname(file), target);
    if (resolved !== skillDir && !resolved.startsWith(skillDir + path.sep)) {
      problems.push(`${rel}: link leaves skill folder: ${target}`);
    }
    if (!fs.existsSync(resolved)) problems.push(`${rel}: dead link ${target}`);
  }
}

console.log(`skill router: ${path.relative(process.cwd(), skillDir)}`);
console.log(`intents: ${dirs.join(', ') || '(none)'}`);
if (problems.length) { console.log('PROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('OK');
