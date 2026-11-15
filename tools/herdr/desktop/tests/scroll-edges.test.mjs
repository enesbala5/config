import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../mods/layout-controls/main.js', import.meta.url), 'utf8');
const keys = JSON.parse(readFileSync(new URL('../keys.json', import.meta.url), 'utf8'));
const piKeys = JSON.parse(readFileSync(new URL('../../../pi/agent/keybindings.json', import.meta.url), 'utf8'));

function load(terminal = 'terminal-1', result = { code: 0 }) {
  const calls = [];
  const sandbox = {
    View: class {}, focused: () => ({ terminal }),
    run: (...args) => calls.push(['run', ...args]),
    hc: async args => { calls.push(['hc', ...args]); return result; },
  };
  vm.createContext(sandbox);
  vm.runInContext(source.replace(/^import .*;\n/gm, '')
    .replace('export default class', 'class'), sandbox);
  return { calls, jump: edge => sandbox.jumpToEdge(edge) };
}

for (const [edge, direction] of [['top', 'up'], ['bottom', 'down']]) {
  test(`${direction} scrolls Herdr then forwards to the same terminal`, async () => {
    assert.equal(keys.terminal[`ctrl-alt-${direction}`], `layout-controls.${edge}`);
    assert.ok(piKeys[`tui.altScreen.${edge}`].includes(`ctrl+alt+${direction}`));
    const { calls, jump } = load();
    await jump(edge);
    assert.equal(JSON.stringify(calls), JSON.stringify([
      ['run', 'terminal.scroll', { terminal: 'terminal-1', to: edge }],
      ['hc', 'keys', 'terminal-1', `ctrl+alt+${direction}`],
    ]));
  });
}

test('no focused terminal is a no-op', async () => {
  const { calls, jump } = load(null);
  await jump('top');
  assert.deepEqual(calls, []);
});

test('forwarding failures are reported', async () => {
  const { jump } = load('terminal-1', { code: 1, stderr: 'PTY unavailable' });
  await assert.rejects(jump('top'), /PTY unavailable/);
});

test('Pi no longer binds Ctrl+End', () => {
  assert.deepEqual(piKeys['tui.altScreen.bottom'], ['ctrl+alt+down']);
});
