import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const config = readFileSync(
  new URL('../../../hypr/hypridle/configuration.conf', import.meta.url),
  'utf8',
);
const dpmsOn = `hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'`;
const dpmsOff = `hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'`;

// Hyprland 0.56's hlDpms reads tableToggleAction: a positional string
// silently falls back to toggle, so an "on" command can switch the panel off.
test('resume explicitly enables the display instead of toggling it', () => {
  const command = config.match(/^\s*after_sleep_cmd\s*=\s*(.+)$/m)?.[1];
  assert.equal(command, dpmsOn);
});

test('idle screen-off and activity use explicit opposite DPMS actions', () => {
  const listener = [...config.matchAll(/listener\s*\{([\s\S]*?)^\}/gm)]
    .map((match) => match[1])
    .find((body) => /timeout\s*=\s*700\b/.test(body));
  assert.ok(listener, 'screen-off listener must exist');
  assert.equal(listener.match(/on-timeout\s*=\s*(.+)/)?.[1], dpmsOff);
  assert.equal(listener.match(/on-resume\s*=\s*(.+)/)?.[1], dpmsOn);
});

test('no DPMS call uses the positional-string form that defaults to toggle', () => {
  assert.doesNotMatch(config, /hl\.dsp\.dpms\(\s*["']/);
});
