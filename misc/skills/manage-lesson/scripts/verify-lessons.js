#!/usr/bin/env node
// Read-only structural check for guide lessons. Orphaned lessons are intended.
// usage: node verify-lessons.js <guide-dir>
const fs = require('fs');
const path = require('path');

const dir = process.argv[2];
if (!dir) { console.error('verify-lessons: usage: node verify-lessons.js <guide-dir>'); process.exit(1); }
if (!fs.existsSync(dir)) { console.error(`verify-lessons: missing ${dir}`); process.exit(1); }

const problems = [];
const buckets = fs.readdirSync(dir, { withFileTypes: true })
  .filter((d) => d.isDirectory() && d.name !== 'misc' && !d.name.startsWith('.'))
  .map((d) => d.name).sort();
let total = 0;

for (const bucket of buckets) {
  const bdir = path.join(dir, bucket);
  const readmePath = path.join(bdir, 'README.md');
  if (!fs.existsSync(readmePath)) { problems.push(`${bucket}/README.md: missing`); continue; }
  const readme = fs.readFileSync(readmePath, 'utf8');
  const files = fs.readdirSync(bdir).filter((f) => f.endsWith('.md') && f !== 'README.md').sort();
  total += files.length;

  for (const f of files) {
    const text = fs.readFileSync(path.join(bdir, f), 'utf8');
    if (!text.startsWith('# ')) problems.push(`${bucket}/${f}: no title`);
    if (!text.includes('**Feeds stage:**')) problems.push(`${bucket}/${f}: no Feeds stage`);
    if (/^Source:/m.test(text)) problems.push(`${bucket}/${f}: unexpected Source: line`);
    if (/misc\/sources|\.\.\/misc\//.test(text)) problems.push(`${bucket}/${f}: links to source archive`);
    if (!readme.includes(`](${f})`)) problems.push(`${bucket}/README.md: ${f} not listed`);
  }
  for (const m of readme.matchAll(/\]\(([^)#]+\.md)\)/g)) {
    if (!files.includes(m[1])) problems.push(`${bucket}/README.md: dead link to ${m[1]}`);
  }
}

console.log(`buckets: ${buckets.length}, lessons: ${total}`);
if (problems.length) { console.log('PROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('OK');
