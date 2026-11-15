// Run: node --test scripts/utilities/tests/screen-record.test.mjs
// All compositor, capture, audio, notification and process-search commands are mocked.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const script = fileURLToPath(new URL('../screen-record.sh', import.meta.url));
function fixture(t, extra = {}) {
  const root = mkdtempSync(join(tmpdir(), 'screenrecord-test-'));
  const bin = join(root, 'bin');
  mkdirSync(bin);
  const windows = [
    { address: '0x123', class: 'test-app', title: 'Test only', mapped: true, stableId: 'stable-test', size: [640, 480], workspace: { id: 99, name: '99' } },
  ];
  const monitors = [
    { name: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1, focused: true, transform: 0 },
    { name: 'DP-2', x: -1080, y: 0, width: 1920, height: 1080, scale: 1, transform: 1 },
  ];
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, TEST_ROOT: root, HOME: root,
    XDG_RUNTIME_DIR: root, XDG_STATE_HOME: join(root, 'logs'), HYPRUSE_CONFINE: '', ...extra };
  const mocks = {
    hyprctl: `
const key = process.argv[3];
if (key === 'monitors') console.log(JSON.stringify(${JSON.stringify(monitors)}));
else if (key === 'clients') console.log(fs.readFileSync(path.join(root, 'windows'), 'utf8'));
else if (key === 'activewindow') console.log('{"address":"0x123"}');
else if (key === 'locked') console.log(JSON.stringify({locked: fs.existsSync(path.join(root, 'locked'))}));
else process.exit(2);`,
    grim: `
if (process.argv.includes('-h')) { console.log('-T <identifier>'); process.exit(); }
if (process.env.FAIL_GRIM) process.exit(1);
fs.appendFileSync(path.join(root, 'capture-calls'), JSON.stringify(process.argv.slice(2)) + '\\n');
process.stdout.write(Buffer.from([255,216,255,217]));`,
    'wl-screenrec': `
fs.writeFileSync(path.join(root, 'encoder-args'), JSON.stringify(process.argv.slice(2)));
if (process.env.FAIL_ENCODER) process.exit(1);
const output = process.argv[process.argv.indexOf('-f') + 1];
fs.writeFileSync(output, 'test video');
const timer = setInterval(() => {}, 1000);
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => { clearInterval(timer); process.exit(0); });`,
    ffmpeg: `
fs.writeFileSync(path.join(root, 'encoder-args'), JSON.stringify(process.argv.slice(2)));
if (process.env.FAIL_ENCODER) process.exit(1);
process.stdin.resume();
process.stdin.on('end', () => { fs.writeFileSync(process.argv.at(-1), 'test video'); process.exit(0); });`,
    pactl: `console.log(process.argv[2] === 'get-default-sink' ? 'test-sink' : 'test-mic');`,
    dunstctl: `
const file = path.join(root, 'paused');
if (process.argv[2] === 'is-paused') console.log(fs.existsSync(file) ? 'true' : 'false');
if (process.argv[2] === 'set-paused') {
  if (process.argv[3] === 'true') fs.writeFileSync(file, '');
  else try { fs.unlinkSync(file); } catch {}
}`,
    'notify-send': `fs.appendFileSync(path.join(root, 'notifications'), process.argv.slice(2).join(' ') + '\\n');`,
    pkill: `fs.appendFileSync(path.join(root, 'pkill'), JSON.stringify(process.argv.slice(2)) + '\\n');`,
    pgrep: `process.exit(process.env.EXTERNAL_RECORDER ? 0 : 1);`,
    'wl-copy': `process.stdin.resume();`,
    'pw-play': `process.exit(0);`,
    slurp: `console.log('5,6 640x480');`,
  };
  for (const [name, body] of Object.entries(mocks)) {
    writeFileSync(join(bin, name), `#!${process.execPath}\nconst fs = require('node:fs'), path = require('node:path');\nconst root = process.env.TEST_ROOT;\n${body}\n`, { mode: 0o755 });
  }
  writeFileSync(join(root, 'windows'), JSON.stringify(windows));
  const run = (args = [], more = {}) => spawnSync('bash', [script, ...args], { env: { ...env, ...more }, encoding: 'utf8', timeout: 18000 });
  const asyncRun = async args => {
    const child = spawn('bash', [script, ...args], { env, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.on('data', b => { stdout += b; }); child.stderr.on('data', b => { stderr += b; });
    const [status] = await once(child, 'close');
    return { status, stdout, stderr };
  };
  const state = () => JSON.parse(readFileSync(join(root, 'screen-record/session.json'), 'utf8'));
  t.after(async () => {
    run(['cancel']);
    await delay(200); // allow the worker's locked finalizer to observe cleared state
    rmSync(root, { recursive: true, force: true });
  });
  return { root, run, asyncRun, state, windows, setWindows: value => writeFileSync(join(root, 'windows'), JSON.stringify(value)), output: join(root, 'video.mp4') };
}
function success(result) { assert.equal(result.status, 0, result.stderr); return result; }

test('help, idle status, and explicit idle stop do not start capture', t => {
  const f = fixture(t);
  assert.match(success(f.run(['--help'])).stdout, /sampled windows/);
  assert.deepEqual(JSON.parse(success(f.run(['status'])).stdout), { text: '', class: 'idle', tooltip: '' });
  success(f.run(['stop']));
  assert.equal(f.run(['is-active']).status, 1);
  assert.equal(existsSync(join(f.root, 'encoder-args')), false);
});

test('list and resolve target exact classes, addresses, active display and rotated negative-coordinate display', t => {
  const f = fixture(t);
  assert.equal(JSON.parse(success(f.run(['list', '--json'])).stdout).windows.length, 1);
  for (const flags of [['--app', 'test-app'], ['--window', '0x123'], ['--window', 'active']]) {
    const resolved = JSON.parse(success(f.run(['resolve', ...flags])).stdout);
    assert.equal(resolved.stableId, 'stable-test');
    assert.equal(resolved.backend, 'grim-ffmpeg');
  }
  assert.equal(JSON.parse(success(f.run(['resolve', '--monitor', 'active'])).stdout).name, 'DP-1');
  assert.equal(JSON.parse(success(f.run(['resolve', '--region', '-1080,0 1080x1920'])).stdout).name, 'DP-2');
  assert.equal(JSON.parse(success(f.run(['resolve', '--region', '-10,10 30x30'])).stdout).geometry, '0,10 20x30');
  assert.notEqual(f.run(['resolve', '--region', '9999,9999 10x10']).status, 0);
  assert.notEqual(f.run(['resolve']).status, 0);
  assert.equal(existsSync(join(f.root, 'encoder-args')), false);
});

test('ambiguous/missing app, missing isolated support, locked session, invalid options fail before capture', t => {
  const f = fixture(t);
  for (const args of [['start', '--app', 'missing'], ['start', '--monitor', 'missing'], ['start', '--duration', '0'], ['start', '--fps', '0'], ['stop', '--window', 'active'], ['stop', '--audio', 'system'], ['resolve', '--duration', '2'], ['start', '--window', 'active', '--monitor', 'DP-1'], ['unknown'], ['start', '--output'], ['start', '--audio', 'nope'], ['start', '--audio', 'none', '--audio-device', 'source'], ['start', '--app', 'test-app', '--fps', '30']]) {
    assert.notEqual(f.run(args).status, 0, args.join(' '));
  }
  f.setWindows([...f.windows, { ...f.windows[0], address: '0x456' }]);
  assert.match(f.run(['resolve', '--app', 'test-app']).stderr, /Ambiguous.*0x456/);
  f.setWindows([{ ...f.windows[0], stableId: null }]);
  assert.match(f.run(['resolve', '--app', 'test-app']).stderr, /no screen-crop fallback/);
  f.setWindows(f.windows);
  writeFileSync(join(f.root, 'locked'), '');
  assert.match(f.run(['start', '--app', 'test-app']).stderr, /locked/);
  assert.equal(existsSync(join(f.root, 'encoder-args')), false);
});

test('display lifecycle preserves DND, rejects second starts, only signals owned process, returns saved path', t => {
  const f = fixture(t);
  const result = JSON.parse(success(f.run(['start', '--monitor', 'DP-1', '--output', f.output, '--json'])).stdout);
  assert.equal(result.active, true);
  assert.equal(existsSync(join(f.root, 'paused')), true);
  assert.notEqual(f.run(['start', '--monitor', 'DP-1']).status, 0);
  assert.notEqual(f.run(['stop', '--bogus']).status, 0);
  success(f.run(['is-active']));
  assert.equal(JSON.parse(success(f.run(['status'])).stdout).class, 'recording');
  const encoderArgs = JSON.parse(readFileSync(join(f.root, 'encoder-args')));
  assert.ok(encoderArgs.includes('test-sink.monitor'));
  assert.equal(success(f.run(['stop'])).stdout.trim(), f.output);
  assert.equal(existsSync(f.output), true);
  assert.equal(existsSync(join(f.root, 'paused')), false);
  assert.doesNotMatch(readFileSync(join(f.root, 'pkill'), 'utf8'), /wl-screenrec|SIGINT|SIGTERM/);
});

test('legacy region toggle works, cancellation discards and preserves preexisting DND', t => {
  const f = fixture(t);
  writeFileSync(join(f.root, 'paused'), '');
  const output = success(f.run()).stdout.trim();
  assert.ok(JSON.parse(readFileSync(join(f.root, 'encoder-args'))).includes('5,6 640x480'));
  success(f.run(['--cancel']));
  assert.equal(existsSync(output), false);
  assert.equal(existsSync(join(f.root, 'paused')), true);
  success(f.run());
  const saved = success(f.run()).stdout.trim();
  assert.equal(existsSync(saved), true);
});

test('sampled hidden-window recording uses only stable toplevel, supports silence and automatic stop', async t => {
  const f = fixture(t);
  success(f.run(['start', '--app', 'test-app', '--audio', 'none', '--duration', '2', '--output', f.output]));
  for (let i = 0; i < 80 && existsSync(join(f.root, 'screen-record/session.json')); i++) await delay(100);
  assert.equal(existsSync(join(f.root, 'screen-record/session.json')), false);
  const last = JSON.parse(readFileSync(join(f.root, 'logs/screen-record/last.json')));
  assert.equal(last.ok, true);
  assert.equal(last.saved, true);
  assert.ok(last.frames > 1);
  const calls = readFileSync(join(f.root, 'capture-calls'), 'utf8').trim().split('\n').map(JSON.parse);
  assert.ok(calls.every(c => c.includes('-T') && c.includes('stable-test') && !c.includes('-g')));
  const encoderArgs = JSON.parse(readFileSync(join(f.root, 'encoder-args')));
  assert.ok(!encoderArgs.includes('pulse'));
  assert.equal(existsSync(join(f.root, 'paused')), false);
});

test('failure before readiness does not silence notifications, truncate an existing output, or kill external recording', t => {
  const f = fixture(t);
  const result = f.run(['start', '--monitor', 'DP-1', '--audio', 'none'], { FAIL_ENCODER: '1' });
  assert.notEqual(result.status, 0);
  assert.equal(existsSync(join(f.root, 'paused')), false);
  assert.equal(f.run(['is-active']).status, 1);
  writeFileSync(f.output, 'keep me');
  assert.notEqual(f.run(['start', '--monitor', 'DP-1', '--output', f.output]).status, 0);
  assert.equal(readFileSync(f.output, 'utf8'), 'keep me');
  assert.match(f.run(['start', '--monitor', 'DP-1'], { EXTERNAL_RECORDER: '1' }).stderr, /unmanaged/);
  assert.match(f.run(['start', '--monitor', 'DP-1'], { HYPRUSE_CONFINE: 'workspace:99' }).stderr, /cannot enforce/);
});

test('PID reuse/stale state never signals an unrelated process', t => {
  const f = fixture(t);
  mkdirSync(join(f.root, 'screen-record'));
  writeFileSync(join(f.root, 'screen-record/session.json'), JSON.stringify({ pid: process.pid, birth: 'wrong', token: 'stale', output: f.output, started: Date.now(), dndManaged: false }));
  success(f.run(['stop']));
  assert.equal(f.run(['is-active']).status, 1);
  assert.equal(existsSync(join(f.root, 'screen-record/session.json')), false);
});

test('concurrent explicit starts serialize: exactly one recording starts', async t => {
  const f = fixture(t);
  const results = await Promise.all([f.asyncRun(['start', '--monitor', 'DP-1']), f.asyncRun(['start', '--monitor', 'DP-1'])]);
  assert.equal(results.filter(r => r.status === 0).length, 1, JSON.stringify(results));
  success(f.run(['is-active']));
});

test('resized target stops sampled capture rather than switching to screen pixels', async t => {
  const f = fixture(t);
  success(f.run(['start', '--app', 'test-app', '--audio', 'none', '--output', f.output]));
  f.setWindows([{ ...f.windows[0], size: [800, 600] }]);
  for (let i = 0; i < 80 && existsSync(join(f.root, 'screen-record/session.json')); i++) await delay(100);
  const last = JSON.parse(readFileSync(join(f.root, 'logs/screen-record/last.json')));
  assert.equal(last.ok, false);
  assert.match(last.error, /resized/);
  assert.equal(existsSync(join(f.root, 'paused')), false);
});

test('manual sampled stop finalizes with explicit audio and no cursor; lock changes fail closed', async t => {
  const f = fixture(t);
  const start = JSON.parse(success(f.run(['start', '--app', 'test-app', '--audio-device', 'explicit-source', '--output', f.output, '--json'])).stdout);
  assert.equal(start.cursor, false);
  const encoderArgs = JSON.parse(readFileSync(join(f.root, 'encoder-args')));
  assert.ok(encoderArgs.includes('explicit-source'));
  assert.ok(encoderArgs.includes('-shortest'));
  const stopped = JSON.parse(success(f.run(['stop', '--json'])).stdout);
  assert.equal(stopped.ok, true);
  assert.equal(stopped.saved, true);
  success(f.run(['start', '--app', 'test-app', '--audio', 'none']));
  writeFileSync(join(f.root, 'locked'), '');
  for (let i = 0; i < 80 && existsSync(join(f.root, 'screen-record/session.json')); i++) await delay(100);
  const last = JSON.parse(readFileSync(join(f.root, 'logs/screen-record/last.json')));
  assert.equal(last.ok, false);
  assert.match(last.error, /locked/);
});

test('supervisor crash recovery finalizes only its registered orphan encoder and restores DND', async t => {
  const f = fixture(t);
  success(f.run(['start', '--monitor', 'DP-1', '--audio', 'none', '--output', f.output]));
  const session = f.state();
  const encoder = JSON.parse(readFileSync(join(f.root, `screen-record/encoder-${session.token}.json`)));
  process.kill(session.pid, 'SIGKILL');
  await delay(50);
  const status = JSON.parse(success(f.run(['status', '--json'])).stdout);
  assert.equal(status.active, false);
  assert.equal(status.last.ok, false);
  assert.equal(existsSync(join(f.root, 'paused')), false);
  // A zombie is already dead for ownership purposes; it may await init's reaper.
  let stat = '';
  try { stat = readFileSync(`/proc/${encoder.pid}/stat`, 'utf8'); } catch {}
  assert.ok(!stat || stat.slice(stat.lastIndexOf(')') + 2).startsWith('Z '));
});
