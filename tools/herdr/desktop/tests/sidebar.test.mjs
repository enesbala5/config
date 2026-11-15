import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function load(mod, { combined = true, inbox = false, width = 256, brand = true, spaceList = [], terminalList = [] } = {}) {
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
    layout: () => tree, theme: () => ({}), props: () => ({}), spaces: () => spaceList, panes: () => [],
    terminals: () => terminalList,
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

function worktreeFixture() {
  const main = { id: 'main', name: 'project', folder: '/project' };
  const other = { id: 'other', name: 'other', folder: '/other', machine: 'remote' };
  const open = { id: 'open', name: 'open', folder: '/trees/open' };
  const { view, calls } = load('spaces-with-worktrees', {
    spaceList: [main, other, open],
    terminalList: [{ state: 'live', cwd: '/trees/agent/src', program: { agent: 'pi' } }],
  });
  const repo = JSON.stringify([null, '/project/.git']);
  const remoteRepo = JSON.stringify(['remote', '/other/.git']);
  const g = { repo, top: main.folder, linked: false, name: 'project', branch: 'dev' };
  Object.assign(view, {
    allWorktrees: new Set(), shown: new Set(['main', 'other', 'open']), born: {},
    git: {
      [JSON.stringify([null, main.folder])]: g,
      [JSON.stringify(['remote', other.folder])]: { ...g, repo: remoteRepo, top: other.folder },
      [JSON.stringify([null, open.folder])]: { ...g, top: open.folder, linked: true },
    },
    wts: {
      [repo]: ['clean', 'dirty', 'agent', 'open'].map(name => ({ path: `/trees/${name}` })),
      [remoteRepo]: [{ path: '/remote/clean' }],
    },
    wtDirty: { '/trees/dirty': true }, pressed: null, over: null,
  });
  return { view, calls, main, g };
}

test('worktree visibility defaults to rules; show-all is per space and reversible', () => {
  const { view } = worktreeFixture();
  const ghosts = () => Array.from(view.ordered().filter(r => r.ghost), r => r.ghost.path);
  assert.deepEqual(ghosts(), ['/trees/dirty', '/trees/agent']);
  assert.ok(view.ordered().some(r => r.w.id === 'open' && r.tree));
  view.allWorktrees.add('main');
  assert.deepEqual(ghosts(), ['/trees/clean', '/trees/dirty', '/trees/agent']);
  view.allWorktrees.delete('main');
  assert.deepEqual(ghosts(), ['/trees/dirty', '/trees/agent']);
});

test('space chevron follows branch, toggles visibility, and isolates row mouse events', () => {
  const { view, calls, main, g } = worktreeFixture();
  const toggle = () => flatten(view.row({ w: main, i: 0, g, tree: null }, {}))
    .find(n => n?.attrs?.id?.[0] === 'space-worktrees-main');
  let stopped = 0, notified = 0;
  const cx = { stop_propagation: () => stopped++, notify: () => notified++ };
  const button = toggle();
  assert.equal(button.attrs.tooltip[0], 'Show all worktrees');
  assert.equal(flatten(button).at(-1).attrs.size[0], 11);
  button.attrs.on_mouse_down[1]({}, cx);
  button.attrs.on_mouse_up[1]({}, cx);
  button.attrs.on_click[0]({}, cx);
  assert.equal(stopped, 3);
  assert.equal(notified, 1);
  assert.equal(view.allWorktrees.has('main'), true);
  assert.equal(view.pressed, null);
  assert.equal(calls.length, 0);
  assert.equal(toggle().attrs.tooltip[0], 'Show only worktrees allowed by visibility rules');
  toggle().attrs.on_click[0]({}, cx);
  assert.equal(view.allWorktrees.has('main'), false);
  for (const git of [{ ...g, linked: true }, { ...g, repo: 'no-worktrees' }, null]) {
    assert.ok(!flatten(view.row({ w: main, i: 0, g: git, tree: null }, {}))
      .some(n => n?.attrs?.id?.[0] === 'space-worktrees-main'));
  }
});
