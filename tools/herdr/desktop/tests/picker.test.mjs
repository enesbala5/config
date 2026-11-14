import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../mods/picker/main.js', import.meta.url), 'utf8');
const agentSource = readFileSync(new URL('../mods/huajar-agents/main.js', import.meta.url), 'utf8');
function load({ spaces = [], agents = [], terminals = [] } = {}) {
  const calls = [];
  const element = () => new Proxy({}, { get: (_, key) => key === 'when'
    ? (condition, fn) => condition ? fn(element()) : element()
    : () => element() });
  const sandbox = {
    View: class {}, div: element, svg: element, image: element, v_flex: element, h_flex: element, Input: { new: element },
    spaces: () => spaces, agents: () => agents, terminals: () => terminals,
    shared: () => ({}), setShared() {}, theme: () => ({}), settings: () => ({ zoom: 1 }),
    props: () => ({}), closeOverlay() {}, run: (...args) => calls.push(args),
  };
  vm.createContext(sandbox);
  vm.runInContext(source.replace(/^import .*;\n/gm, '').replace('export default class Picker', 'class Picker') + '\nthis.api = { Picker, sessionTitle, tabTitle, duration };', sandbox);
  const picker = new sandbox.api.Picker();
  Object.assign(picker, { filter: '', machines: [], showEarlier: false, at: null, scroll: 0 });
  return { ...sandbox.api, picker, calls };
}
const pi = { key: 'pi', name: 'Pi', icon: 'icons/pi.svg', tint: true };
const fixture = {
  spaces: [{ id: 'w1', name: 'config', active: true, status: 'working', tabs: [
    { id: 't1', name: '1', active: true, status: 'working' },
    { id: 't2', name: 'Release checklist', named: true, status: 'idle' },
    { id: 't3', name: '3' },
  ] }],
  agents: [
    { address: 'a1', tab: 't1', title: 'π · Herdr Picker Titles · config', program: pi },
    { address: 'a2', tab: 't2', title: 'Ignored session', program: pi },
  ],
};

test('title cleanup stays identical to the Agents pane', () => {
  const helper = (s, end) => s.slice(s.indexOf('const GLYPH'), s.indexOf(end)).trim();
  assert.equal(helper(source, '\nfunction duration'), helper(agentSource, 'const wtTag'));
});

test('unnamed tabs show cleaned session titles; named tabs and shells keep names', () => {
  const rows = load(fixture).picker.rows().filter(r => r.kind === 'ctx');
  assert.deepEqual(Array.from(rows, r => r.title), ['Herdr Picker Titles', 'Release checklist', '3']);
});

test('search matches session titles, original titles, programs, tab names and spaces', () => {
  const { picker } = load(fixture);
  for (const [filter, count] of [['picker titles', 1], ['ignored session', 1], ['pi', 2], ['checklist', 1], ['config', 3], ['missing', 0]]) {
    picker.filter = filter;
    assert.equal(picker.rows().filter(r => r.kind === 'ctx').length, count, filter);
  }
});

test('multiple agents contribute distinct titles and descendant counts', () => {
  const data = { ...fixture, agents: [...fixture.agents, { address: 'a3', tab: 't1', title: 'Second task', program: pi }], terminals: [
    { address: 'kid', parent: 'a1', state: 'live' },
    { address: 'grandkid', parent: 'kid', state: 'live' },
    { address: 'old', parent: 'a1', state: 'exited' },
  ] };
  const row = load(data).picker.rows().find(r => r.kind === 'ctx');
  assert.equal(row.title, 'Herdr Picker Titles · Second task');
  assert.equal(row.team, 2);
});

test('render and tab navigation keep existing tab IDs', () => {
  const { picker, calls } = load(fixture);
  assert.ok(picker.render());
  picker.go(picker.rows().find(r => r.kind === 'ctx'));
  assert.equal(calls[0][0], 'tab.select');
  assert.equal(calls[0][1].id, 't1');
});

test('unhelpful titles fall back; durations match Agents pane units', () => {
  const { sessionTitle, tabTitle, duration } = load();
  for (const title of ['', 'Pi', 'π', 'e@host']) assert.equal(sessionTitle(title, pi, 'config'), null, title);
  assert.equal(tabTitle({ name: '1' }, [{ title: 'Pi', program: pi }], 'config'), '1');
  assert.deepEqual([0, 60000, 3600000, 86400000].map(duration), ['<1m', '1m', '1h', '1d']);
});
