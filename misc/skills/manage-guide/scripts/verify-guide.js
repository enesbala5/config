#!/usr/bin/env node
// Read-only integrity check for a guide's archived sources.
// usage: node verify-guide.js <guide-dir>
const fs = require('fs');
const path = require('path');

const dir = process.argv[2];
if (!dir) { console.error('verify-guide: usage: node verify-guide.js <guide-dir>'); process.exit(1); }
const sourcesDir = path.join(dir, 'misc', 'sources');
if (!fs.existsSync(sourcesDir)) { console.error(`verify-guide: missing ${sourcesDir}`); process.exit(1); }

const problems = [];
const files = fs.readdirSync(sourcesDir).filter((f) => f.endsWith('.md') && f !== 'README.md').sort();
const required = ['title', 'source', 'author', 'captured']; // published is optional (some pages have no date)

for (const f of files) {
  const text = fs.readFileSync(path.join(sourcesDir, f), 'utf8');
  const lines = text.split('\n');
  if (lines[0] !== '---') { problems.push(`${f}: no frontmatter`); continue; }
  const end = lines.indexOf('---', 1);
  if (end < 0) { problems.push(`${f}: unterminated frontmatter`); continue; }
  const meta = {};
  for (const line of lines.slice(1, end)) {
    const m = line.match(/^([a-z_]+):\s*(.*)$/);
    if (m) meta[m[1]] = m[2].replace(/^"|"$/g, '');
  }
  for (const key of required) if (!meta[key]) problems.push(`${f}: missing/empty ${key}`);
  const body = lines.slice(end + 1).join('\n').trim();
  if (body.length < 200) problems.push(`${f}: body suspiciously short (${body.length} chars)`);
}

const readmePath = path.join(sourcesDir, 'README.md');
if (fs.existsSync(readmePath)) {
  const readme = fs.readFileSync(readmePath, 'utf8');
  for (const f of files) {
    if (!readme.includes(`](${f})`) && !readme.includes(f)) problems.push(`README.md: ${f} not listed`);
  }
} else problems.push('misc/sources/README.md: missing');

console.log(`sources: ${files.length}`);
if (problems.length) { console.log('PROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('OK');
