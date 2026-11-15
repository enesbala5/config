import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../mods/layout-controls/main.js', import.meta.url), 'utf8');
const keys = JSON.parse(readFileSync(new URL('../keys.json', import.meta.url), 'utf8'));
const piKeys = JSON.parse(readFileSync(new URL('../../../pi/agent/keybindings.json', import.meta.url), 'utf8'));

function load(terminal = 'terminal-1') {
  const calls = [], actions = [], commands = [];
  let resolveCommand;
  const sandbox = {
    View: class {}, focused: () => ({ terminal }), props: () => ({}),
    run: (...args) => calls.push(args),
    window: { dispatch_action: action => actions.push(action) },
    nextCommand: () => commands.length ? Promise.resolve(commands.shift())
      : new Promise(resolve => { resolveCommand = resolve; }),
  };
  vm.createContext(sandbox);
  vm.runInContext(source.replace(/^import .*;\n/gm, '')
    .replace('export default class', 'this.Mod = class'), sandbox);
  new sandbox.Mod().init({}, { spawn: fn => { fn({ notify() {} }); } });
  return {
    calls, actions, jump: edge => sandbox.jumpToEdge(edge),
    focus: value => { terminal = value; },
    async deliver(command) {
      if (resolveCommand) { const resolve = resolveCommand; resolveCommand = null; resolve(command); }
      else commands.push(command);
      await new Promise(resolve => setImmediate(resolve));
    },
  };
}

for (const [edge, direction, code] of [['top', 'up', 'A'], ['bottom', 'down', 'B']]) {
  test(`${direction} uses native input then scrolls the original terminal without hc`, async () => {
    assert.equal(keys.terminal[`ctrl-alt-${direction}`], `layout-controls.${edge}`);
    assert.ok(piKeys[`tui.altScreen.${edge}`].includes(`ctrl+alt+${direction}`));
    const mod = load();
    await mod.deliver(edge);
    assert.deepEqual(mod.actions, [
      `send:\u001b[1;7${code}`,
      `layout-controls.scroll:${JSON.stringify({ terminal: 'terminal-1', to: edge })}`,
    ]);
    assert.deepEqual(mod.calls, []);
    mod.focus('terminal-2');
    await mod.deliver(mod.actions[1].slice('layout-controls.'.length));
    assert.equal(JSON.stringify(mod.calls), JSON.stringify([
      ['terminal.scroll', { terminal: 'terminal-1', to: edge }],
    ]));
  });
}

test('no focused terminal is a no-op', () => {
  const mod = load(null);
  mod.jump('top');
  assert.deepEqual(mod.actions, []);
  assert.deepEqual(mod.calls, []);
});

test('Pi no longer binds Ctrl+End', () => {
  assert.deepEqual(piKeys['tui.altScreen.bottom'], ['ctrl+alt+down']);
});
