// Run: node --test scripts/utilities/tests/manage-sunshine.test.mjs
// Mock systemd/journald; never touch the real streaming session.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('../manage-sunshine.sh', import.meta.url));
function fixture(t, extra = {}) {
  const root = mkdtempSync(join(tmpdir(), 'manage-sunshine-test-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const env = { ...process.env, PATH: `${root}:${process.env.PATH}`, TEST_ROOT: root,
    WAYLAND_DISPLAY: 'wayland-1', HYPRLAND_INSTANCE_SIGNATURE: 'test-session', ...extra };
  for (const name of ['DISPLAY', 'XDG_CURRENT_DESKTOP', 'XDG_SESSION_TYPE']) delete env[name];
  writeFileSync(join(root, 'systemctl'), `#!${process.execPath}
const fs = require('node:fs');
const args = process.argv.slice(2);
const root = process.env.TEST_ROOT;
fs.appendFileSync(root + '/calls', JSON.stringify(args) + '\\n');
const command = args[1];
if (command === process.env.FAIL_COMMAND) { console.error('mock systemd failure'); process.exit(1); }
if (command === 'import-environment') {
  for (const name of args.slice(2)) {
    if (!process.env[name]) { console.error('unset variable: ' + name); process.exit(1); }
  }
  fs.writeFileSync(root + '/session-type', process.env.XDG_SESSION_TYPE || '');
}
if (['start', 'restart', 'stop'].includes(command)) {
  fs.writeFileSync(root + '/state', command === 'stop' ? 'inactive' : 'active');
}
if (command === 'show') {
  if (process.env.BAD_STATE && args[2] === process.env.BAD_UNIT) console.log(process.env.BAD_STATE);
  else console.log(fs.readFileSync(root + '/state', 'utf8'));
}
if (command === 'status') { console.log('mock service diagnostics'); process.exit(3); }
`, { mode: 0o755 });
  writeFileSync(join(root, 'journalctl'), '#!/usr/bin/env bash\nprintf "mock journal diagnostics\\n"\n', { mode: 0o755 });
  writeFileSync(join(root, 'sleep'), '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 });
  writeFileSync(join(root, 'state'), 'inactive');
  return {
    root,
    run: (args, more = {}) => spawnSync('bash', [script, ...args], { env: { ...env, ...more }, encoding: 'utf8', timeout: 10000 }),
    calls: () => readFileSync(join(root, 'calls'), 'utf8').trim().split('\n').map(JSON.parse),
  };
}
function success(result) {
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '');
  return result.stdout;
}

test('off reports progress and confirms both services are stopped, including repeated off', t => {
  const f = fixture(t);
  for (let i = 0; i < 2; i++) {
    assert.match(success(f.run(['off'])), /Stopping Sunshine[\s\S]*Sunshine is OFF; both services are stopped/);
  }
  assert.deepEqual(f.calls()[0], ['--user', 'stop', 'sunshine-session.service', 'sunshine.service']);
});

test('on handles missing optional variables and explicitly starts both units', t => {
  const f = fixture(t);
  assert.match(success(f.run(['on'])), /Starting Sunshine[\s\S]*Sunshine is ON[\s\S]*https:\/\/localhost:47990/);
  assert.deepEqual(f.calls()[0], ['--user', 'import-environment', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE', 'XDG_SESSION_TYPE']);
  assert.equal(readFileSync(join(f.root, 'session-type'), 'utf8'), 'wayland');
  assert.deepEqual(f.calls()[1], ['--user', 'start', 'sunshine-session.service', 'sunshine.service']);
  assert.match(success(f.run(['on'])), /Sunshine is ON/);
});

test('restart imports populated optional variables and reports success', t => {
  const f = fixture(t);
  assert.match(success(f.run(['restart'], { DISPLAY: ':0', XDG_CURRENT_DESKTOP: 'Hyprland' })), /Restarting Sunshine[\s\S]*Sunshine is ON/);
  assert.ok(f.calls()[0].includes('DISPLAY'));
  assert.ok(f.calls()[0].includes('XDG_CURRENT_DESKTOP'));
  assert.equal(f.calls()[1][1], 'restart');
});

test('missing Hyprland session fails with an actionable message before calling systemd', t => {
  const f = fixture(t);
  const result = f.run(['on'], { WAYLAND_DISPLAY: '' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Error: no Hyprland session[\s\S]*terminal inside the laptop Hyprland session/);
});

for (const [command, failCommand] of [['on', 'import-environment'], ['on', 'start'], ['restart', 'restart'], ['off', 'stop']]) {
  test(`${command}: ${failCommand} failure prints diagnostics, never success`, t => {
    const f = fixture(t);
    const result = f.run([command], { FAIL_COMMAND: failCommand });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /mock systemd failure[\s\S]*Error:[\s\S]*mock service diagnostics[\s\S]*mock journal diagnostics[\s\S]*manage-sunshine logs/);
    assert.doesNotMatch(result.stdout, /Sunshine is (ON|OFF)/);
  });
}

for (const unit of ['sunshine.service', 'sunshine-session.service']) {
  test(`successful start job with failed ${unit} is not reported as ON`, t => {
    const f = fixture(t);
    const result = f.run(['on'], { BAD_STATE: 'failed', BAD_UNIT: unit });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Service states:.*failed[\s\S]*Error:[\s\S]*mock journal diagnostics/);
    assert.doesNotMatch(result.stdout, /Sunshine is ON/);
  });
}

test('off refuses to claim success while Sunshine is still active', t => {
  const f = fixture(t);
  const result = f.run(['off'], { BAD_STATE: 'active', BAD_UNIT: 'sunshine.service' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /watcher=inactive, sunshine=active[\s\S]*Error:/);
  assert.doesNotMatch(result.stdout, /Sunshine is OFF/);
});

test('status preserves systemctl exit status; help and invalid usage remain available', t => {
  const f = fixture(t);
  assert.equal(f.run(['status']).status, 3);
  assert.match(success(f.run(['help'])), /Usage: manage-sunshine/);
  assert.equal(f.run(['invalid']).status, 2);
  assert.equal(f.run(['on', 'extra']).status, 2);
  assert.match(success(f.run(['logs'])), /Following Sunshine logs[\s\S]*mock journal diagnostics/);
});
