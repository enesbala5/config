import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function load(mod, { combined = true, inbox = false, width = 256, brand = true } = {}) {
  const calls = [];
  function node() {
    const children = [], attrs = {};
    const proxy = new Proxy({ children, attrs }, { get(target, key) {
      if (key === 'when') return (condition, fn) => condition ? fn(proxy) : proxy;
      if (key === 'child') return child => { children.push(child); return proxy; };
      if (key === 'children') return Object.assign(list => { children.push(...list); return proxy; }, { list: children });
      if (key === 'attrs') return attrs;
      return (...args) => { attrs[key] = args; return proxy; };
    } });
    return proxy;
  }
  const tree = { children: [
    { id: 'brand', content: { mod: brand ? 'layout-controls' : 'other' } },
    { id: 'spaces', content: { mod: combined ? 'spaces-with-worktrees' : 't3-spaces' } },
    { id: 'sidebar', size: { px: width } },
    { id: 'sidebar-lists', active: inbox ? 'inbox' : 'lists' },
  ] };
  const sandbox = { View: class {}, div: node, svg: node, h_flex: node, v_flex: node,
    layout: () => tree, theme: () => ({}), props: () => ({}), spaces: () => [], panes: () => [],
    machines: () => [], shared: () => ({}), setShared() {}, run: (...args) => calls.push(args),
  };
  vm.createContext(sandbox);
  const source = readFileSync(new URL(`../mods/${mod}/main.js`, import.meta.url), 'utf8');
  vm.runInContext(source.replace(/^import .*;\n/gm, '').replace(/export default class (\w+)/, 'this.Mod = class $1').replace(/^export /gm, ''), sandbox);
  const view = new sandbox.Mod();
  return { view, calls };
}
function flatten(node) {
  if (typeof node !== 'object') return [node];
  return [node, ...node.children.list.flatMap(flatten)];
}

test('combined header orders title, inbox toggle, sidebar toggle, plus', () => {
  const { view, calls } = load('layout-controls');
  const nodes = flatten(view.render());
  assert.deepEqual(nodes.filter(n => n?.attrs?.id).map(n => n.attrs.id[0]), ['brand', 'sidebar-mode', 'sidebar-toggle', 'space-new']);
  assert.ok(nodes.includes('Spaces'));
  nodes.find(n => n?.attrs?.id?.[0] === 'space-new').attrs.on_click[0]();
  assert.equal(calls[0][0], 'space.new');
});

test('other layouts retain their original brand controls', () => {
  const nodes = flatten(load('layout-controls', { combined: false }).view.render());
  assert.ok(!nodes.includes('Spaces'));
  assert.ok(!nodes.some(n => n?.attrs?.id?.[0] === 'space-new'));
});

test('inbox and collapsed headers do not show an incorrect Spaces label', () => {
  const inbox = flatten(load('layout-controls', { inbox: true }).view.render());
  assert.ok(inbox.includes('Inbox'));
  assert.ok(!inbox.some(n => n?.attrs?.id?.[0] === 'space-new'));
  assert.ok(!flatten(load('layout-controls', { width: 100 }).view.render()).includes('Spaces'));
});

test('machine headers have 16px spacing except the first, including folded machines', () => {
  for (const collapsed of [false, true]) {
    const { view } = load('spaces-with-worktrees');
    Object.assign(view, { ordered: () => [], machines: [{ name: 'a' }, { name: 'b' }], folded: new Set(['a']) });
    const heads = view.grouped({}, collapsed).filter(n => n.attrs.id?.[0]?.startsWith('machine-') && !n.attrs.id[0].startsWith('machine-new-'));
    assert.deepEqual(Array.from(heads, n => n.attrs.mt?.[0]), [undefined, 16, 16]);
  }
});

test('spaces list omits its duplicate header only when layout-controls owns it', () => {
  for (const brand of [true, false]) {
    const { view } = load('spaces-with-worktrees', { brand });
    view.grouped = () => [];
    const nodes = flatten(view.render());
    assert.equal(nodes.includes('Spaces'), !brand);
  }
});
