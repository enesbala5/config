import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('../network-serve', import.meta.url));
const host = 'fixture.example.ts.net';
const mapping = (port, upstream) => ({
  TCP: { [port]: { HTTPS: true } },
  Web: { [`${host}:${port}`]: { Handlers: { '/': { Proxy: upstream } } } },
});
async function fixture(t, initial = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'network-serve-test-'));
  const server = net.createServer(socket => socket.end());
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => { server.close(); fs.rmSync(dir, { recursive: true, force: true }); });
  const appPort = server.address().port;
  const upstream = `http://127.0.0.1:${appPort}`;
  fs.writeFileSync(path.join(dir, 'config.json'), JSON.stringify(initial));
  fs.writeFileSync(path.join(dir, 'calls.json'), '[]');
  fs.writeFileSync(path.join(dir, 'tailscale'), `#!/usr/bin/env node
const fs = require('node:fs');
const root = process.env.FAKE_ROOT;
const args = process.argv.slice(2);
const calls = JSON.parse(fs.readFileSync(root + '/calls.json'));
calls.push(args); fs.writeFileSync(root + '/calls.json', JSON.stringify(calls));
let cfg = JSON.parse(fs.readFileSync(root + '/config.json'));
if (args[0] === 'status') {
  console.log(JSON.stringify({ BackendState: process.env.FAKE_OFFLINE ? 'Stopped' : 'Running', Self: { DNSName: '${host}.' }, TailscaleIPs: ['127.0.0.99'] }));
} else if (args[1] === 'status') {
  if (process.env.FAKE_BAD_JSON) console.log('broken');
  else console.log(JSON.stringify(cfg));
} else {
  if (process.env.FAKE_FAIL) { console.error('permission denied'); process.exit(1); }
  const p = args.find(a => a.startsWith('--https=')).split('=')[1];
  cfg.TCP ||= {}; cfg.Web ||= {};
  if (args.at(-1) === 'off') { delete cfg.TCP[p]; delete cfg.Web['${host}:' + p]; }
  else {
    cfg.TCP[p] = { HTTPS: true };
    cfg.Web['${host}:' + p] = { Handlers: { '/': { Proxy: args.at(-1) } } };
  }
  if (!process.env.FAKE_NO_CHANGE) fs.writeFileSync(root + '/config.json', JSON.stringify(cfg));
  console.log('Tailscale human-readable output must not leak into stdout');
}
`, { mode: 0o700 });
  const env = { ...process.env, PATH: `${dir}:${process.env.PATH}`, XDG_STATE_HOME: path.join(dir, 'state'), FAKE_ROOT: dir };
  const run = (args, extra = {}) => spawnSync(process.execPath, [script, ...args], { env: { ...env, ...extra }, encoding: 'utf8', timeout: 10000 });
  const read = () => JSON.parse(fs.readFileSync(path.join(dir, 'config.json')));
  const write = value => fs.writeFileSync(path.join(dir, 'config.json'), JSON.stringify(value));
  const calls = () => JSON.parse(fs.readFileSync(path.join(dir, 'calls.json')));
  const mutations = () => calls().filter(args => args[0] === 'serve' && args[1] !== 'status');
  return { dir, appPort, upstream, run, read, write, calls, mutations };
}

test('help and skill need no Tailscale and create no state', () => {
  for (const flag of ['--help', '--skill']) {
    const result = spawnSync(process.execPath, [script, flag], { env: { PATH: '/nonexistent' }, encoding: 'utf8' });
    assert.equal(result.status, 0);
    assert.match(result.stdout, /network-serve/);
    assert.equal(result.stderr, '');
  }
});

test('creates a clean persistent HTTPS root URL, reuses it, and stops only its mapping', async t => {
  const f = await fixture(t);
  const first = f.run([String(f.appPort)]);
  assert.equal(first.status, 0, first.stderr);
  assert.match(first.stdout, new RegExp(`^https://${host.replaceAll('.', '\\.')}(:\\d+)?/\\n$`));
  assert.equal(first.stderr, '');
  const created = f.mutations()[0];
  assert.ok(created.includes('--bg'));
  assert.ok(created.includes('--yes'));
  const p = +created.find(arg => arg.startsWith('--https=')).split('=')[1];
  if (p === 443) assert.equal(first.stdout, `https://${host}/\n`);
  const second = f.run([`http://localhost:${f.appPort}/settings?x=a%20b#details`]);
  assert.equal(second.status, 0, second.stderr);
  assert.equal(second.stdout, first.stdout.trimEnd() + 'settings?x=a%20b#details\n');
  assert.equal(f.mutations().length, 1);
  const stop = f.run(['--stop', String(f.appPort)]);
  assert.equal(stop.status, 0, stop.stderr);
  assert.equal(stop.stdout, '');
  assert.equal(f.read().TCP[p], undefined);
  assert.equal(f.run(['--stop', String(f.appPort)]).status, 1);
});

test('preserves existing 443 and foreground mappings, allocating another port', async t => {
  const initial = mapping(443, 'http://127.0.0.1:7317');
  initial.Foreground = { anotherSession: mapping(8443, 'http://127.0.0.1:7777') };
  const f = await fixture(t, initial);
  const result = f.run([String(f.appPort)]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `https://${host}:8444/\n`);
  assert.deepEqual(f.read().Web[`${host}:443`], initial.Web[`${host}:443`]);
  assert.deepEqual(f.read().Foreground, initial.Foreground);
});

test('reuses existing private mapping without claiming ownership', async t => {
  const f = await fixture(t);
  f.write(mapping(8443, f.upstream));
  const result = f.run([String(f.appPort)]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `https://${host}:8443/\n`);
  assert.equal(f.mutations().length, 0);
  const stop = f.run(['--stop', String(f.appPort)]);
  assert.equal(stop.status, 1);
  assert.match(stop.stderr, /no mapping owned/);
});

test('never reuses Funnel or a mapping with sibling paths', async t => {
  const f = await fixture(t);
  const initial = mapping(443, f.upstream);
  initial.AllowFunnel = { [`${host}:443`]: true };
  Object.assign(initial.TCP, mapping(8443, f.upstream).TCP);
  Object.assign(initial.Web, mapping(8443, f.upstream).Web);
  initial.Web[`${host}:8443`].Handlers['/other'] = { Text: 'keep me' };
  f.write(initial);
  const result = f.run([String(f.appPort)]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `https://${host}:8444/\n`);
  assert.deepEqual(f.read().AllowFunnel, initial.AllowFunnel);
});

test('refuses cleanup when mapping was changed or made public', async t => {
  const f = await fixture(t);
  assert.equal(f.run([String(f.appPort)]).status, 0);
  const cfg = f.read();
  const p = Object.keys(cfg.TCP)[0];
  cfg.Web[`${host}:${p}`].Handlers['/extra'] = { Text: 'someone else' };
  f.write(cfg);
  const before = f.mutations().length;
  const result = f.run(['--stop', String(f.appPort)]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /refusing/);
  assert.equal(f.mutations().length, before);
  delete cfg.Web[`${host}:${p}`].Handlers['/extra'];
  cfg.AllowFunnel = { [`${host}:${p}`]: true };
  f.write(cfg);
  assert.equal(f.run(['--stop', String(f.appPort)]).status, 1);
  assert.equal(f.mutations().length, before);
});

test('two apps keep independent mappings and stopping one preserves the other', async t => {
  const f = await fixture(t, mapping(443, 'http://127.0.0.1:7317'));
  const other = await fixture(t);
  const first = f.run([String(f.appPort)]);
  const second = f.run([String(other.appPort)]);
  assert.equal(first.status, 0, first.stderr);
  assert.equal(second.status, 0, second.stderr);
  assert.notEqual(first.stdout, second.stdout);
  const secondPort = new URL(second.stdout.trim()).port;
  const retained = f.read().Web[`${host}:${secondPort}`];
  assert.equal(f.run(['--stop', String(f.appPort)]).status, 0);
  assert.deepEqual(f.read().Web[`${host}:${secondPort}`], retained);
  assert.equal(f.read().Web[`${host}:443`].Handlers['/'].Proxy, 'http://127.0.0.1:7317');
  assert.equal(f.run(['--stop', String(other.appPort)]).status, 0);
});

test('refuses removal when a handler has extra behavior', async t => {
  const f = await fixture(t);
  assert.equal(f.run([String(f.appPort)]).status, 0);
  const cfg = f.read();
  const p = Object.keys(cfg.TCP)[0];
  cfg.Web[`${host}:${p}`].Handlers['/'].Text = 'changed';
  f.write(cfg);
  assert.equal(f.run(['--stop', String(f.appPort)]).status, 1);
  assert.equal(f.mutations().length, 1);
});

test('normalizes wildcard loopback input and preserves encoded paths', async t => {
  const f = await fixture(t);
  const result = f.run([`http://0.0.0.0:${f.appPort}/a%2Fb?q=%23#anchor`]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /\/a%2Fb\?q=%23#anchor\n$/);
  assert.equal(f.mutations()[0].at(-1), f.upstream);
});

test('rejects unsafe inputs without invoking Tailscale', async t => {
  const f = await fixture(t);
  for (const args of [[], ['--unknown'], ['0'], ['65536'], ['https://example.com'], ['file:///etc/passwd'], ['http://user:pass@localhost:3000'], ['3000', '4000'], ['--stop', '0']]) {
    const result = f.run(args);
    assert.equal(result.status, 1, JSON.stringify(args));
    assert.equal(result.stdout, '');
  }
  assert.deepEqual(f.calls(), []);
});

test('offline, malformed status, permission failures and unconfirmed writes produce no URL', async t => {
  const f = await fixture(t);
  for (const extra of [{ FAKE_OFFLINE: '1' }, { FAKE_BAD_JSON: '1' }, { FAKE_FAIL: '1' }, { FAKE_NO_CHANGE: '1' }]) {
    const result = f.run([String(f.appPort)], extra);
    assert.equal(result.status, 1);
    assert.equal(result.stdout, '');
    assert.match(result.stderr, /network-serve:/);
  }
});

test('unreachable app does not publish a port', async t => {
  const f = await fixture(t);
  const socket = net.createServer();
  await new Promise(resolve => socket.listen(0, '127.0.0.1', resolve));
  const unused = socket.address().port;
  await new Promise(resolve => socket.close(resolve));
  const result = f.run([String(unused)]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /not reachable/);
  assert.equal(f.mutations().length, 0);
});

test('occupied local HTTPS port is skipped', async t => {
  const f = await fixture(t, mapping(443, 'http://127.0.0.1:7317'));
  const listener = net.createServer();
  try { await new Promise((resolve, reject) => { listener.once('error', reject); listener.listen(8443, '127.0.0.99', resolve); }); }
  catch { t.skip('test port already occupied'); return; }
  t.after(() => listener.close());
  const result = f.run([String(f.appPort)]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `https://${host}:8444/\n`);
});

test('concurrent invocation lock and corrupt ownership state fail closed', async t => {
  const f = await fixture(t);
  const state = path.join(f.dir, 'state/network-serve');
  fs.mkdirSync(path.join(state, 'lock'), { recursive: true });
  assert.match(f.run([String(f.appPort)]).stderr, /another invocation/);
  fs.rmdirSync(path.join(state, 'lock'));
  fs.writeFileSync(path.join(state, 'mappings.json'), '{broken');
  assert.equal(f.run([String(f.appPort)]).status, 1);
  assert.equal(f.mutations().length, 0);
});
