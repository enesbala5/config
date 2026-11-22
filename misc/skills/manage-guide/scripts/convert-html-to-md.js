#!/usr/bin/env node
// HTML -> Markdown archive with frontmatter.
// Requires jsdom, @mozilla/readability, turndown available via NODE_PATH
// (see reference/md-tooling.md). No harness-specific APIs.
const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('convert-html-to-md: ' + msg); process.exit(1); }

const [htmlPath, outPath, ...rest] = process.argv.slice(2);
if (!htmlPath || !outPath) fail('usage: node convert-html-to-md.js <raw.html> <out.md> [--source-url URL] [--title T] [--author A] [--published D]');

const flags = {};
for (let i = 0; i < rest.length; i += 2) flags[rest[i]] = rest[i + 1] || '';

let raw = fs.readFileSync(htmlPath, 'utf8');
let html = raw;
try { if (raw.trimStart().startsWith('"')) html = JSON.parse(raw); } catch (_) { /* already HTML */ }

let JSDOM, Readability, TurndownService;
try {
  ({ JSDOM } = require('jsdom'));
  ({ Readability } = require('@mozilla/readability'));
  TurndownService = require('turndown');
} catch (e) {
  fail('missing deps; npm install jsdom @mozilla/readability turndown and set NODE_PATH to its node_modules');
}

const url = flags['--source-url'] || 'about:blank';
const dom = new JSDOM(html, { url });
let bodyHtml = dom.window.document.body.innerHTML;
let title = flags['--title'] || dom.window.document.title || 'Untitled';
try {
  const article = new Readability(dom.window.document, { charThreshold: 100 }).parse();
  if (article && article.content) {
    bodyHtml = article.content;
    if (!flags['--title'] && article.title) title = article.title.trim();
  }
} catch (_) { /* fall back to body */ }

const td = new TurndownService({ headingStyle: 'atx', codeBlockStyle: 'fenced', bulletListMarker: '-', emDelimiter: '*' });
td.addRule('strip-noise', {
  filter: ['script', 'style', 'noscript', 'svg', 'iframe', 'form', 'nav', 'footer', 'header'],
  replacement: () => '',
});
td.addRule('images', {
  filter: ['img'],
  replacement: (_content, node) => {
    const src = node.getAttribute('src') || node.getAttribute('data-src') || '';
    if (!src) return '';
    const alt = (node.getAttribute('alt') || '').replace(/[\[\]]/g, '');
    return `\n\n![${alt}](${src})\n\n`;
  },
});

const esc = (s) => String(s || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ');
const today = new Date().toISOString().slice(0, 10);
const front = [
  '---',
  `title: "${esc(title)}"`,
  `source: ${flags['--source-url'] || ''}`,
  `author: "${esc(flags['--author'] || '')}"`,
  flags['--published'] ? `published: "${esc(flags['--published'])}"` : null,
  `captured: "${esc(flags['--captured'] || today)}"`,
  '---', '',
].filter(Boolean).join('\n');

const body = td.turndown(bodyHtml)
  .replace(/\n{3,}/g, '\n\n')
  .replace(/[ \t]+\n/g, '\n')
  .trim();
const md = `${front}\n# ${title}\n\n${body}\n`;
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, md);
console.log(`wrote ${outPath} (${md.split(/\s+/).length} words)`);
