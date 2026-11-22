#!/usr/bin/env node
// X status/article -> Markdown archive using public JSON APIs (no login).
// usage: node fetch-x-to-md.js <status-id> <out.md> [handle]
const fs = require('fs');
const path = require('path');

function fail(msg) { console.error('fetch-x-to-md: ' + msg); process.exit(1); }
const [id, outPath, handle] = process.argv.slice(2);
if (!id || !outPath) fail('usage: node fetch-x-to-md.js <status-id> <out.md> [handle]');

const esc = (s) => String(s || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ');

async function getJSON(url) {
  const res = await fetch(url, { headers: { 'User-Agent': 'guide-archiver/1.0' } });
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  return res.json();
}

(async () => {
  let data;
  const endpoints = [`https://api.fxtwitter.com/status/${id}`];
  if (handle) endpoints.push(`https://api.vxtwitter.com/${handle.replace(/^@/, '')}/status/${id}`);
  let lastError;
  for (const url of endpoints) {
    try { data = await getJSON(url); break; } catch (e) { lastError = e; }
  }
  if (!data) fail(`all endpoints failed: ${lastError && lastError.message}`);

  const tweet = data.tweet || data;
  const article = tweet.article || {};
  const url = `https://x.com/${(tweet.author && tweet.author.screen_name) || handle || 'i'}/status/${id}`;
  const title = article.title || `X post ${id}`;
  const author = tweet.author
    ? `${tweet.author.name || ''} (@${tweet.author.screen_name || ''})`.trim()
    : '';
  const published = article.created_at || tweet.created_at || '';

  let body = '';
  const blocks = article.content && Array.isArray(article.content.blocks) ? article.content.blocks : [];
  if (blocks.length) {
    body = blocks.map((b) => {
      const text = (b.text || '').trim();
      if (!text) return '';
      switch (b.type) {
        case 'header-one': return '# ' + text;
        case 'header-two': return '## ' + text;
        case 'header-three': return '### ' + text;
        case 'unordered-list-item': return '- ' + text;
        case 'ordered-list-item': return '1. ' + text;
        default: return text;
      }
    }).filter(Boolean).join('\n\n');
  }
  if (!body) body = (tweet.text || '').trim();
  if (!body) fail('API returned no text; not writing a stub');

  const today = new Date().toISOString().slice(0, 10);
  const front = [
    '---',
    `title: "${esc(title)}"`,
    `source: ${url}`,
    `author: "${esc(author)}"`,
    published ? `published: "${esc(published)}"` : null,
    `captured: "${esc(today)}"`,
    '---', '',
  ].filter(Boolean).join('\n');
  const md = `${front}\n# ${title}\n\n${body}\n`;
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, md);
  console.log(`wrote ${outPath} (${md.split(/\s+/).length} words)`);
})().catch((e) => fail(e.message));
