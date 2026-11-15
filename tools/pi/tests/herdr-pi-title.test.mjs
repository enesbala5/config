import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import net from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

const source = stripTypeScriptTypes(readFileSync(new URL('../agent/extensions/herdr-pi-title.ts', import.meta.url), 'utf8'));
const tick = () => new Promise(setImmediate);
let serial = 0;
async function fixture(t, { env = {}, name, opener, complete } = {}) {
	const keys = ['HERDR_ENV', 'HERDR_SOCKET_PATH', 'HERDR_PANE_ID', 'HC_TERMINAL_ID'];
	const saved = Object.fromEntries(keys.map(k => [k, process.env[k]]));
	for (const k of keys) delete process.env[k];
	Object.assign(process.env, env);
	const { default: extension } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}#${serial++}`);
	for (const k of keys) {
		if (saved[k] === undefined) delete process.env[k];
		else process.env[k] = saved[k];
	}
	// Environment is checked when the extension factory runs, too.
	const oldDesktop = process.env.HC_TERMINAL_ID;
	if (env.HC_TERMINAL_ID) process.env.HC_TERMINAL_ID = env.HC_TERMINAL_ID;
	else delete process.env.HC_TERMINAL_ID;
	const handlers = {}, names = [], calls = [];
	let current = name;
	const ctx = {
		mode: 'tui', cwd: '/home/e/dev/seo', model: { id: 'mini', provider: 'test' },
		modelRegistry: { complete: async (...args) => {
			calls.push(args);
			return complete ? complete(...args) : { content: [{ type: 'text', text: 'SEO PR #401 Review' }] };
		} },
		sessionManager: { getBranch: () => opener ? [{ type: 'message', message: { role: 'user', content: opener } }] : [] },
	};
	extension({
		on(event, fn) { handlers[event] = fn; },
		getSessionName: () => current,
		setSessionName(value) {
			current = value;
			names.push(value);
			handlers.session_info_changed?.({ name: value }, ctx);
		},
	});
	if (oldDesktop === undefined) delete process.env.HC_TERMINAL_ID;
	else process.env.HC_TERMINAL_ID = oldDesktop;
	t.after(() => handlers.session_shutdown?.());
	return { handlers, ctx, names, calls, name: () => current, rename: value => { current = value; } };
}
const desktop = { HC_TERMINAL_ID: 'test-terminal' };

test('desktop enables auto-naming without any TUI variables', async t => {
	const f = await fixture(t, { env: desktop });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Please review SEO pull request #401' }, f.ctx);
	await tick();
	assert.equal(f.name(), 'SEO PR #401 Review');
	assert.match(f.calls[0][1].systemPrompt, /distinctive/);
	assert.match(f.calls[0][1].systemPrompt, /project, feature, component/);
	assert.match(f.calls[0][1].messages[0].content[0].text, /Working directory: \/home\/e\/dev\/seo/);
});

test('fallback retains subject, PR hash and activity when the model fails', async t => {
	const f = await fixture(t, { env: desktop, complete: () => { throw Error('offline'); } });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Please review SEO pull request #401' }, f.ctx);
	await tick();
	assert.equal(f.name(), 'SEO PR #401 review');
});

test('fallback extracts repository and PR number from a GitHub link', async t => {
	const f = await fixture(t, { env: desktop, complete: () => { throw Error('offline'); } });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Review https://github.com/team/seo/pull/401' }, f.ctx);
	await tick();
	assert.equal(f.name(), 'Seo PR #401 Review');
});

test('model title preserves #401, acronyms and backticked component names', async t => {
	const f = await fixture(t, { env: desktop, complete: () => ({ content: [{ type: 'text', text: '`SEO` PR #401 Review extra words' }] }) });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Review SEO PR #401' }, f.ctx);
	await tick();
	assert.equal(f.name(), 'SEO PR #401 Review');
});

test('reload names an existing unnamed conversation without a new prompt', async t => {
	const f = await fixture(t, { env: desktop, opener: 'Review SEO pull request #401' });
	await f.handlers.session_start({ reason: 'reload' }, f.ctx);
	await tick();
	assert.equal(f.name(), 'SEO PR #401 Review');
});

test('manual session names are not overwritten', async t => {
	const f = await fixture(t, { env: desktop, name: 'My deliberate title', opener: 'Review SEO pull request #401' });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Review something else' }, f.ctx);
	await tick();
	assert.equal(f.name(), 'My deliberate title');
	assert.equal(f.calls.length, 0);
});

test('manual rename during generation wins', async t => {
	let finish;
	const pending = new Promise(resolve => { finish = resolve; });
	const f = await fixture(t, { env: desktop, complete: () => pending });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Review SEO PR #401' }, f.ctx);
	f.rename('User title');
	finish({ content: [{ type: 'text', text: 'SEO PR #401 Review' }] });
	await tick();
	assert.equal(f.name(), 'User title');
});

test('new session can generate its own title; late previous generation cannot rename it', async t => {
	let finish;
	const pending = new Promise(resolve => { finish = resolve; });
	const f = await fixture(t, { env: desktop, complete: () => pending });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Review SEO PR #401' }, f.ctx);
	f.rename(undefined);
	await f.handlers.session_start({ reason: 'new' }, f.ctx);
	finish({ content: [{ type: 'text', text: 'Old task title' }] });
	await tick();
	assert.equal(f.name(), undefined);
	f.handlers.before_agent_start({ prompt: 'Fix Stripe webhooks' }, f.ctx);
	await tick();
	assert.equal(f.calls.length, 2);
});

test('shutdown blocks late generation results', async t => {
	let finish;
	const f = await fixture(t, { env: desktop, complete: () => new Promise(resolve => { finish = resolve; }) });
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Review SEO PR #401' }, f.ctx);
	f.handlers.session_shutdown();
	const before = f.names.length;
	finish({ content: [{ type: 'text', text: 'Late title' }] });
	await tick();
	assert.equal(f.names.length, before);
});

for (const mode of ['rpc', 'json', 'print']) test(`${mode} mode never generates or renames`, async t => {
	const f = await fixture(t, { env: desktop });
	f.ctx.mode = mode;
	await f.handlers.session_start({}, f.ctx);
	f.handlers.before_agent_start({ prompt: 'Review SEO PR #401' }, f.ctx);
	assert.deepEqual(f.names, []);
	assert.deepEqual(f.calls, []);
});

test('ordinary terminals do not install Herdr title handlers', async t => {
	const f = await fixture(t);
	assert.deepEqual(f.handlers, {});
});

test('TUI metadata still reports title with TTL and clears at shutdown', async t => {
	const dir = mkdtempSync(join(tmpdir(), 'pi-title-'));
	const socket = join(dir, 'herdr.sock');
	const requests = [];
	const server = net.createServer(connection => {
		connection.on('data', chunk => {
			requests.push(JSON.parse(String(chunk)));
			connection.end('{"ok":true}\n');
		});
	});
	await new Promise(resolve => server.listen(socket, resolve));
	t.after(async () => { await new Promise(resolve => server.close(resolve)); rmSync(dir, { recursive: true }); });
	const f = await fixture(t, { env: { HERDR_ENV: '1', HERDR_SOCKET_PATH: socket, HERDR_PANE_ID: 'w1:p1' }, name: 'SEO PR #401 Review' });
	await f.handlers.session_start({}, f.ctx);
	for (let i = 0; i < 30 && !requests.length; i++) await tick();
	assert.equal(requests[0].method, 'pane.report_metadata');
	assert.equal(requests[0].params.title, 'SEO PR #401 Review');
	assert.equal(requests[0].params.pane_id, 'w1:p1');
	assert.equal(requests[0].params.ttl_ms, 300000);
	f.handlers.session_shutdown();
	for (let i = 0; i < 30 && !requests.some(r => r.params.clear_title); i++) await tick();
	assert.ok(requests.some(r => r.params.clear_title));
});
