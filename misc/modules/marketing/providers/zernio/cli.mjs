#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';

const usage = 'marketing-zernio accounts WORKSPACE | status WORKSPACE POST_ID | analytics WORKSPACE [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--platform P] [--sort engagement|date] [--limit N] | posts WORKSPACE --account-id ID [--limit N] | search WORKSPACE --query QUERY [--account-id ID] [--limit N] | (draft|schedule|publish) WORKSPACE --request-id ID < post.json';
const normalize = p => p === 'x' ? 'twitter' : p;
const string = v => typeof v === 'string' && v.trim().length > 0;
const date = v => /^\d{4}-\d{2}-\d{2}$/.test(v ?? '');
const count = (v, min, max) => { const n = Number(v); return Number.isInteger(n) && n >= min && n <= max; };
class Problem extends Error {}
function check(ok, message) { if (!ok) throw new Problem(message); }
function parse(raw, label) {
  try { return JSON.parse(raw); } catch { throw new Problem(`Invalid JSON in ${label}`); }
}

export async function run(argv, { load, input, fetcher = fetch }) {
  const { values, positionals: [cmd, workspace, id, ...extra] } = parseArgs({
    args: argv, allowPositionals: true,
    options: {
      'request-id': { type: 'string' }, 'account-id': { type: 'string' },
      query: { type: 'string' }, platform: { type: 'string' },
      from: { type: 'string' }, to: { type: 'string' },
      sort: { type: 'string' }, limit: { type: 'string' },
    },
  });
  const create = ['draft', 'schedule', 'publish'].includes(cmd);
  const reads = ['accounts', 'status', 'analytics', 'posts', 'search'].includes(cmd);
  check((create || reads) && workspace && !extra.length && (cmd === 'status' ? /^[\w-]+$/.test(id ?? '') : !id), usage);
  const requestId = values['request-id'];
  check(create ? /^[\w-]{1,128}$/.test(requestId ?? '') : requestId === undefined, usage);
  const config = parse(await load(), 'Zernio secret');
  check(config?.workspaces && Object.hasOwn(config.workspaces, workspace), 'Workspace not configured');
  const ws = config.workspaces[workspace];
  check(string(ws?.key) && Array.isArray(ws.accounts) && ws.accounts.length && ws.accounts.every(string), 'Workspace requires key and nonempty accounts list');
  const allowed = ws.accounts.map(normalize);
  async function api(path, params, body) {
    const query = params && new URLSearchParams(params).toString();
    const res = await fetcher(`https://zernio.com/api/v1/${path}${query ? `?${query}` : ''}`, {
      method: body ? 'POST' : 'GET', redirect: 'error', signal: AbortSignal.timeout(30000),
      headers: { Authorization: `Bearer ${ws.key}`, ...(body && { 'Content-Type': 'application/json', 'x-request-id': requestId }) },
      ...(body && { body: JSON.stringify(body) })
    });
    if (!res.ok) {
      let detail = '';
      try {
        const e = await res.json();
        if (string(e?.error)) detail = `: ${[e.code, e.error].filter(string).join(' — ')}`;
      } catch {}
      throw new Problem(`Zernio returned HTTP ${res.status}${detail}`);
    }
    return res.json();
  }
  const summary = data => {
    const post = data?.post ?? data;
    const postId = post?._id ?? post?.id;
    check(string(postId), 'Missing post ID in Zernio response; check dashboard before retrying');
    return { postId, status: post.status, urls: (post.platforms ?? []).map(p => p.platformPostUrl).filter(Boolean) };
  };
  if (cmd === 'status') return summary(await api(`posts/${id}`));
  if (cmd === 'analytics') {
    const from = values.from, to = values.to, platform = values.platform, sort = values.sort, limit = values.limit;
    check(!from || date(from), '--from must be YYYY-MM-DD');
    check(!to || date(to), '--to must be YYYY-MM-DD');
    check(!platform || allowed.includes(normalize(platform)), 'Platform not configured for this workspace');
    check(!sort || /^\w{1,64}$/.test(sort), 'Invalid --sort');
    check(!limit || count(limit, 1, 100), '--limit must be 1..100');
    const params = { view: 'summary' };
    if (from) params.fromDate = from;
    if (to) params.toDate = to;
    if (platform) params.platform = normalize(platform);
    if (sort) params.sortBy = sort;
    if (limit) params.limit = limit;
    return api('analytics', params);
  }
  const { accounts } = await api('accounts');
  check(Array.isArray(accounts), 'Unexpected Zernio accounts response');
  const connected = accounts.filter(a => allowed.includes(normalize(a.platform)) && a.isActive !== false).map(a => ({ platform: normalize(a.platform), accountId: a._id ?? a.accountId ?? a.id, username: a.username }));
  check(connected.every(a => string(a.accountId)), 'Connected account missing ID');
  if (cmd === 'posts') {
    const accountId = values['account-id'];
    check(string(accountId) && connected.some(a => a.accountId === accountId), 'Use --account-id with a connected account ID');
    check(!values.limit || count(values.limit, 1, 100), '--limit must be 1..100');
    const data = await api(`accounts/${accountId}/posts`, values.limit ? { limit: values.limit } : undefined);
    return { account: connected.find(a => a.accountId === accountId), ...data };
  }
  if (cmd === 'search') {
    check(string(values.query), 'search requires --query');
    check(!values.limit || count(values.limit, 10, 100), '--limit must be 10..100');
    const xAccounts = connected.filter(a => a.platform === 'twitter');
    check(xAccounts.length, 'No connected X account; search needs X analytics enabled');
    check(!values['account-id'] || xAccounts.some(a => a.accountId === values['account-id']), '--account-id must be a connected X account');
    check(values['account-id'] || xAccounts.length === 1, `Multiple X accounts: use --account-id (${xAccounts.map(a => a.username).join(', ')})`);
    const account = xAccounts.find(a => !values['account-id'] || a.accountId === values['account-id']);
    const params = { accountId: account.accountId, query: values.query };
    if (values.limit) params.limit = values.limit;
    return api('twitter/search', params);
  }
  if (!create) return connected;
  const post = parse(await input(), 'post input');
  check(Array.isArray(post?.platforms) && post.platforms.length, 'post.platforms must be a nonempty array');
  // Explicit subcommand owns the delivery mode. Never forward a conflicting flag.
  for (const k of ['isDraft', 'publishNow']) check(!Object.hasOwn(post, k), `Omit ${k}; use the delivery subcommand`);
  if (cmd === 'schedule') check(string(post.scheduledFor) && string(post.timezone), 'schedule requires scheduledFor and timezone');
  else check(!Object.hasOwn(post, 'scheduledFor') && !Object.hasOwn(post, 'timezone'), 'Scheduling fields require schedule');
  if (cmd === 'draft') post.isDraft = true;
  if (cmd === 'publish') post.publishNow = true;
  post.platforms = post.platforms.map(p => {
    const platform = normalize(p?.platform);
    check(allowed.includes(platform), 'Platform not configured for this workspace');
    const matches = connected.filter(a => a.platform === platform && (!Object.hasOwn(p, 'accountId') || a.accountId === p.accountId));
    check(matches.length, `No matching connected ${platform} account`);
    check(matches.length === 1, `Multiple ${platform} accounts: use accounts to choose an accountId`);
    return { ...p, platform, accountId: matches[0].accountId };
  });
  return summary(await api('posts', undefined, post));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    console.log(JSON.stringify(await run(process.argv.slice(2), {
      load: () => readFile('/run/agenix/zernio-secrets.json', 'utf8').catch(() => { throw new Problem('Cannot read /run/agenix/zernio-secrets.json'); }),
      input: async () => { let text = ''; for await (const chunk of process.stdin.setEncoding('utf8')) text += chunk; return text; }
    }), null, 2));
  } catch (e) {
    console.error(e instanceof Problem ? e.message : `Request or arguments invalid. Usage: ${usage}`);
    process.exitCode = 1;
  }
}
