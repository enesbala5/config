#!/usr/bin/env node
// Implementation for screen-record.sh. Requires Node 22+, Linux /proc, Hyprland.
import { spawn, spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { existsSync, mkdirSync, readFileSync, writeFileSync, renameSync, unlinkSync, statSync, openSync, closeSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const here = dirname(fileURLToPath(import.meta.url));
const wrapper = join(here, 'screen-record.sh');
const runtime = process.env.XDG_RUNTIME_DIR || join(process.env.TMPDIR || '/tmp', `screen-record-${process.getuid()}`);
const stateDir = join(runtime, 'screen-record');
const logDir = join(process.env.XDG_STATE_HOME || join(process.env.HOME, '.local/state'), 'screen-record');
const stateFile = join(stateDir, 'session.json');
const logFile = join(logDir, 'last.log');
const lastFile = join(logDir, 'last.json');
const defaultDest = join(process.env.HOME, 'misc/media/Screen Recordings');
const args = process.argv.slice(2);
const help = `Usage: screen-record.sh [COMMAND] [OPTIONS]

No arguments: select a region with slurp, or stop our active recording.
Commands:
  start       Start explicitly; never toggles an existing recording off
  stop        Stop and finalize our recording (prints saved path)
  cancel      Stop and discard our recording (--cancel also works)
  status      Waybar JSON; --json gives structured session state
  is-active   Exit 0 only while our recording is alive
  list        List monitors and windows (add --json for machine-readable data)
  resolve     Resolve a target without recording or changing focus (JSON)

Targets (exactly one for start/resolve; start defaults to interactive --region):
  --monitor NAME|active   One display, native wl-screenrec backend
  --window ADDRESS|active Isolated surface, including hidden workspaces
  --app CLASS            Exact Hyprland class; ambiguous matches fail with candidates
  --region 'X,Y WxH'      Display pixels; clipped to the most-overlapped display
  --region               Interactive slurp picker (start only)

Start options:
  --output PATH.mp4      Must not exist; default ~/misc/media/Screen Recordings/
  --duration SECONDS     Automatic stop, 2..86400 seconds
  --audio system|mic|none  Default system, preserving the keyboard shortcut behavior
  --audio-device SOURCE Explicit PulseAudio source (instead of --audio)
  --fps N               Default 30 for displays, 10 for sampled windows (max 15)
  --no-cursor           Omit cursor (sampled windows omit it by default)
  --json                Structured result instead of a path

Window capture uses repeated grim -T frames + FFmpeg, NOT a full-motion stream.
It never falls back to a screen crop. Keep a fixed window size during recording.
Hidden apps may stop rendering. Audio is system-wide unless explicitly selected.
Logs: ${logFile}
`;

function run(cmd, argv = [], options = {}) {
  const result = spawnSync(cmd, argv, { encoding: 'utf8', timeout: 8000, ...options });
  if (result.error || result.status !== 0) throw new Error(`${cmd}: ${result.error?.message || result.stderr?.trim() || `exit ${result.status}`}`);
  return result.stdout;
}
function optional(cmd, argv = []) { try { return run(cmd, argv).trim(); } catch { return ''; } }
function json(path) { try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return null; } }
function save(path, value) {
  const temp = `${path}.${process.pid}.tmp`;
  writeFileSync(temp, JSON.stringify(value), { mode: 0o600 });
  renameSync(temp, path);
}
function remove(path) { try { unlinkSync(path); } catch (e) { if (e.code !== 'ENOENT') throw e; } }
function birth(pid) {
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, 'utf8');
    const fields = stat.slice(stat.lastIndexOf(')') + 2).split(' ');
    return fields[0] === 'Z' ? null : fields[19];
  } catch { return null; }
}
function alive(session) { return !!session?.pid && !!session.birth && birth(session.pid) === session.birth; }
function refresh() { for (const signal of ['-RTMIN+9', '-RTMIN+10']) optional('pkill', [signal, 'waybar']); }
function dnd(on) { optional(join(here, 'dnd-toggle.sh'), [on ? 'on' : 'off']); }
function notify(title, body) { optional('notify-send', [title, body]); }
function sound(name) {
  const path = `/run/current-system/sw/share/sounds/freedesktop/stereo/${name}.oga`;
  if (existsSync(path)) spawn('pw-play', [path], { stdio: 'ignore' }).on('error', () => {});
}
function resultPath(token) { return join(stateDir, `result-${token}.json`); }
function readyPath(token) { return join(stateDir, `ready-${token}.json`); }
function encoderPath(token) { return join(stateDir, `encoder-${token}.json`); }
function sessionStatus(session) {
  return { ...session, active: alive(session), elapsed: Math.max(0, Math.floor((Date.now() - session.started) / 1000)) };
}
function finish(session, result, discard = false) {
  if (session.dndManaged && !session.dndWasPaused) dnd(false);
  if (discard) remove(session.output);
  const saved = !discard && existsSync(session.output) && statSync(session.output).size > 0;
  const outcome = { ...session, ...result, active: false, saved, discarded: discard, finished: Date.now() };
  save(lastFile, outcome);
  remove(stateFile);
  remove(readyPath(session.token));
  remove(resultPath(session.token));
  remove(encoderPath(session.token));
  refresh();
  if (discard) notify('Screen recording cancelled', 'Discarded');
  else if (result?.ok && saved) { sound('complete'); notify('Screen recording stopped', session.output); }
  else notify('Screen recording failed', `${result?.error || 'Recorder disappeared'}. See ${logFile}`);
  return outcome;
}
async function reconcile() {
  const session = json(stateFile);
  if (session && !alive(session)) {
    // If the supervisor crashed, finalize only its registered encoder, never another process.
    const encoder = json(encoderPath(session.token));
    if (alive(encoder)) {
      process.kill(encoder.pid, 'SIGINT');
      for (let i = 0; i < 120 && alive(encoder); i++) await delay(50);
      if (alive(encoder)) throw new Error('Orphaned encoder did not finalize; state retained for recovery');
    }
    finish(session, json(resultPath(session.token)) || { ok: false, error: 'Recorder disappeared' });
  }
  return json(stateFile);
}
function assertUnlocked() {
  const state = JSON.parse(run('hyprctl', ['-j', 'locked']));
  if (state.locked !== false) throw new Error('Session is locked or lock state is unknown; isolated capture refused');
}
function desktop() {
  return { monitors: JSON.parse(run('hyprctl', ['-j', 'monitors'])).filter(m => !m.disabled), windows: JSON.parse(run('hyprctl', ['-j', 'clients'])) };
}
function logicalMonitor(m) {
  const rotated = Number(m.transform || 0) % 2 === 1;
  return { ...m, lw: Math.round((rotated ? m.height : m.width) / m.scale), lh: Math.round((rotated ? m.width : m.height) / m.scale) };
}
function resolveRegion(geometry, monitors) {
  const match = /^(-?\d+),(-?\d+)\s+(\d+)x(\d+)$/.exec(geometry);
  if (!match) throw new Error("Region must be 'X,Y WxH'");
  const [x, y, w, h] = match.slice(1).map(Number);
  if (!w || !h) throw new Error('Region must have positive dimensions');
  const overlap = m => Math.max(0, Math.min(x + w, m.x + m.lw) - Math.max(x, m.x)) * Math.max(0, Math.min(y + h, m.y + m.lh) - Math.max(y, m.y));
  const m = monitors.map(logicalMonitor).sort((a, b) => overlap(b) - overlap(a))[0];
  if (!m || !overlap(m)) throw new Error('Selection is not on a display');
  const slop = Math.ceil(m.lw * 0.006) + 2;
  if (x <= m.x + slop && y <= m.y + slop && x + w >= m.x + m.lw - slop && y + h >= m.y + m.lh - slop)
    return { kind: 'monitor', name: m.name, backend: 'wl-screenrec' };
  const cx = Math.max(x, m.x), cy = Math.max(y, m.y);
  return { kind: 'region', geometry: `${cx},${cy} ${Math.min(x + w, m.x + m.lw) - cx}x${Math.min(y + h, m.y + m.lh) - cy}`, monitor: m.name, backend: 'wl-screenrec' };
}
function resolveTarget(options, interactive = false) {
  const { monitors, windows } = desktop();
  const type = options.target || 'region';
  let value = options.value;
  if (type === 'region') {
    if (!value) {
      if (!interactive) throw new Error('resolve needs an explicit region or target; no picker is opened');
      value = run('slurp', [], { timeout: 0 }).trim();
      if (!value) throw new Error('No area selected');
    }
    return resolveRegion(value, monitors);
  }
  if (type === 'monitor') {
    const matches = monitors.filter(m => value === 'active' ? m.focused : m.name === value);
    if (matches.length !== 1) throw new Error(`Monitor not found: ${value}`);
    return { kind: 'monitor', name: matches[0].name, backend: 'wl-screenrec' };
  }
  const active = type === 'window' && value === 'active' ? JSON.parse(run('hyprctl', ['-j', 'activewindow'])).address : value;
  const matches = windows.filter(w => w.mapped && (type === 'app' ? w.class === value : w.address === active));
  if (matches.length !== 1) throw new Error(`${matches.length ? 'Ambiguous app' : 'Window not found'}: ${value}. Candidates: ${JSON.stringify(matches.map(w => ({ address: w.address, class: w.class, title: w.title })))}`);
  const w = matches[0];
  assertUnlocked();
  if (!w.stableId) throw new Error('Isolated window capture needs Hyprland stableId + grim -T; no screen-crop fallback');
  if (!run('grim', ['-h']).includes('-T ')) throw new Error('Isolated window capture needs grim 1.5+ with -T');
  return { kind: 'window', address: w.address, class: w.class, title: w.title, stableId: w.stableId, size: w.size, backend: 'grim-ffmpeg', sampled: true };
}
function parse(argv) {
  const options = { audio: 'system', json: false, cursor: true };
  const commands = ['start', 'stop', 'cancel', '--cancel', 'status', 'is-active', 'list', 'resolve', '_finish'];
  let command = 'toggle';
  if (argv[0] && !argv[0].startsWith('--')) {
    command = argv.shift();
    if (!commands.includes(command)) throw new Error(`Unknown command: ${command}`);
  } else if (argv[0] === '--cancel') { argv.shift(); command = 'cancel'; }
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (flag === '--json') { options.json = true; continue; }
    if (flag === '--no-cursor') { options.cursor = false; continue; }
    if (!['--monitor', '--window', '--app', '--region', '--output', '--duration', '--audio', '--audio-device', '--fps'].includes(flag)) throw new Error(`Unknown option: ${flag}`);
    let value;
    if (flag === '--region' && (!argv[i + 1] || argv[i + 1].startsWith('--'))) value = '';
    else {
      value = argv[++i];
      if (!value || value.startsWith('--')) throw new Error(`Missing value for ${flag}`);
    }
    if (['--monitor', '--window', '--app', '--region'].includes(flag)) {
      if (options.target) throw new Error('Choose exactly one target');
      options.target = flag.slice(2); options.value = value;
    } else options[flag.slice(2)] = value;
  }
  if (!['start', 'toggle', 'resolve'].includes(command) && argv.some(arg => arg !== '--json')) throw new Error(`${command} does not take recording options`);
  if (command === 'resolve' && argv.some(arg => ['--output', '--duration', '--audio', '--audio-device', '--fps', '--no-cursor'].includes(arg))) throw new Error('resolve only takes target options and --json');
  if (!['system', 'mic', 'none'].includes(options.audio)) throw new Error('--audio must be system, mic, or none');
  if (options['audio-device'] && argv.includes('--audio')) throw new Error('Choose --audio or --audio-device, not both');
  if (options.duration !== undefined && (!Number.isFinite(Number(options.duration)) || Number(options.duration) < 2 || Number(options.duration) > 86400)) throw new Error('--duration must be between 2 and 86400 seconds');
  if (options.fps !== undefined && (!/^\d+$/.test(options.fps) || +options.fps < 1 || +options.fps > 120)) throw new Error('--fps must be an integer from 1 to 120');
  if (command === 'toggle' && argv.length) command = 'start';
  return { command, options };
}
function audioSource(options) {
  if (options['audio-device']) return options['audio-device'];
  if (options.audio === 'none') return null;
  const device = run('pactl', [options.audio === 'mic' ? 'get-default-source' : 'get-default-sink']).trim();
  if (!device) throw new Error('Audio source unavailable; specify --audio none or --audio-device SOURCE');
  return options.audio === 'system' ? `${device}.monitor` : device;
}
async function stop(session, discard, options) {
  if (!session) { if (options.json) console.log(JSON.stringify({ active: false })); return; }
  if (alive(session)) process.kill(session.pid, 'SIGTERM');
  let result;
  for (let i = 0; i < 240; i++) {
    result = json(resultPath(session.token));
    if (result || !alive(session)) break;
    await delay(50);
  }
  if (alive(session) && !result) throw new Error('Recorder did not finalize within 12 seconds; state retained, inspect last.log');
  const outcome = finish(session, result || { ok: false, error: 'Recorder disappeared before finalization' }, discard);
  if (outcome.saved && outcome.ok) spawnSync('wl-copy', [], { input: outcome.output, timeout: 2000 });
  if (options.json) console.log(JSON.stringify(outcome));
  else if (outcome.saved) console.log(outcome.output);
  if (!discard && !outcome.ok) process.exitCode = 1;
}
async function start(options) {
  if (process.env.HYPRUSE_CONFINE) throw new Error('HYPRUSE_CONFINE is set; this recorder cannot enforce that scope. Do not bypass the confinement setting');
  if (await reconcile()) throw new Error('A recording is already active; use stop or cancel');
  // Do not interfere with a legacy/independent wl-screenrec process.
  if (spawnSync('pgrep', ['-x', 'wl-screenrec'], { stdio: 'ignore', timeout: 2000 }).status === 0) throw new Error('An unmanaged wl-screenrec is running; stop it separately before starting');
  const target = resolveTarget(options, true);
  const fps = Number(options.fps || (target.kind === 'window' ? 10 : 30));
  if (target.kind === 'window' && fps > 15) throw new Error('Sampled window capture supports --fps 1..15; use a display for full-motion recording');
  const output = resolve(options.output || join(defaultDest, `${new Date().toISOString().replaceAll(':', '-').replace('T', '-').replace('Z', '')}-${randomUUID().slice(0, 6)}.mp4`));
  if (!output.endsWith('.mp4')) throw new Error('--output must end with .mp4');
  if (existsSync(output)) throw new Error(`Output already exists: ${output}`);
  const audio = audioSource(options);
  mkdirSync(dirname(output), { recursive: true });
  const session = { token: randomUUID(), output, target, fps, audio, cursor: target.kind !== 'window' && options.cursor, duration: Number(options.duration || 0), started: Date.now(), dndWasPaused: optional('dunstctl', ['is-paused']) === 'true', dndManaged: false };
  const log = openSync(logFile, 'w', 0o600);
  const child = spawn(wrapper, ['_worker', JSON.stringify(session)], { detached: true, stdio: ['ignore', log, log] });
  closeSync(log);
  await new Promise((res, rej) => { child.once('spawn', res); child.once('error', rej); });
  session.pid = child.pid; session.birth = birth(child.pid);
  child.unref();
  save(stateFile, session);
  for (let i = 0; i < 200; i++) {
    const ready = json(readyPath(session.token));
    const result = json(resultPath(session.token));
    if (ready?.ok && alive(session) && !result) {
      // Persist restoration intent before changing the user's notification state.
      session.dndManaged = true;
      save(stateFile, session);
      dnd(true); refresh(); sound('message-new-instant');
      console.log(options.json ? JSON.stringify(sessionStatus(session)) : output);
      return;
    }
    if (result || !alive(session)) {
      finish(session, result || { ok: false, error: 'Recorder failed during startup' });
      throw new Error(`Recording failed; see ${logFile}`);
    }
    await delay(50);
  }
  await stop(session, false, { json: false });
  throw new Error(`Recorder did not become ready; see ${logFile}`);
}

// Worker owns only its own encoder/capture children. It never scans or kills by process name.
async function worker(session) {
  let stopping = false, encoder, capture, timer, feeder, encoderSignalled = false;
  let watchdog;
  let failure = null;
  const requestStop = () => { stopping = true; if (capture) capture.kill('SIGTERM'); };
  process.on('SIGTERM', requestStop);
  process.on('SIGINT', requestStop);
  const audioArgs = session.audio ? ['-f', 'pulse', '-i', session.audio] : [];
  try {
    let command, argv;
    if (session.target.kind === 'window') {
      command = 'ffmpeg';
      argv = ['-hide_banner', '-loglevel', 'warning', '-n', '-f', 'image2pipe', '-framerate', String(session.fps), '-vcodec', 'mjpeg', '-i', 'pipe:0', ...audioArgs, '-map', '0:v:0', ...(session.audio ? ['-map', '1:a:0', '-c:a', 'aac', '-shortest'] : []), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', session.output];
    } else {
      command = 'wl-screenrec';
      argv = [session.target.kind === 'monitor' ? '-o' : '-g', session.target.name || session.target.geometry, '-f', session.output, '--max-fps', String(session.fps), ...(session.cursor ? [] : ['--no-cursor']), ...(session.audio ? ['--audio', '--audio-device', session.audio] : [])];
    }
    encoder = spawn(command, argv, { stdio: [session.target.kind === 'window' ? 'pipe' : 'ignore', 'ignore', 'inherit'] });
    let encoderError;
    encoder.on('error', e => { encoderError = e; });
    if (encoder.pid) save(encoderPath(session.token), { pid: encoder.pid, birth: birth(encoder.pid) });
    encoder.stdin?.on('error', e => { if (!stopping) failure ||= e; });
    const exited = new Promise(res => { encoder.once('exit', (code, signal) => res({ code, signal })); encoder.once('error', () => res({ code: 1 })); });
    let frames = 0;
    if (session.target.kind === 'window') {
      feeder = (async () => {
        const startTime = performance.now();
        while (!stopping && encoder.exitCode === null && !encoderError) {
          const frameStart = performance.now();
          // Check the compositor, not a process-name guess: a crashed locker can stay locked.
          assertUnlocked();
          const clients = JSON.parse(run('hyprctl', ['-j', 'clients']));
          const target = clients.find(w => w.address === session.target.address && w.stableId === session.target.stableId && w.mapped);
          if (!target) throw new Error('Target window closed or changed identity');
          if (JSON.stringify(target.size) !== JSON.stringify(session.target.size)) throw new Error('Target resized; keep the window size fixed during a sampled recording');
          capture = spawn('grim', ['-T', session.target.stableId, '-t', 'jpeg', '-q', '95', '-'], { stdio: ['ignore', 'pipe', 'inherit'] });
          const current = capture;
          const chunks = [];
          current.stdout.on('data', b => chunks.push(b));
          const captureTimeout = setTimeout(() => current.kill('SIGKILL'), 5000);
          let code;
          try { [code] = await once(current, 'close'); } finally { clearTimeout(captureTimeout); capture = null; }
          if (stopping) break;
          if (code !== 0 || !chunks.length) throw new Error('grim isolated capture failed; no screen-crop fallback');
          const frame = Buffer.concat(chunks);
          // Duplicate the latest frame when capture misses its budget, preserving wall-clock duration.
          const due = Math.max(frames + 1, Math.floor((performance.now() - startTime) * session.fps / 1000) + 1);
          while (frames < due && !stopping) {
            await new Promise((res, rej) => encoder.stdin.write(frame, error => error ? rej(error) : res()));
            frames++;
          }
          await delay(Math.max(0, 1000 / session.fps - (performance.now() - frameStart)));
        }
      })().catch(e => { failure ||= e; requestStop(); });
    }
    const began = Date.now();
    timer = setInterval(() => {
      if (encoderError) { failure ||= encoderError; requestStop(); }
      if (session.duration && Date.now() - began >= session.duration * 1000) requestStop();
      if (!stopping && (session.target.kind !== 'window' || frames >= 2) && Date.now() - began >= 1000 && encoder.exitCode === null && !encoderError && !existsSync(readyPath(session.token))) save(readyPath(session.token), { ok: true });
      if (stopping && session.target.kind !== 'window' && !encoderSignalled) { encoderSignalled = true; encoder.kill('SIGINT'); }
      // Install this even while the frame feeder is waiting on encoder backpressure.
      if (stopping && !watchdog) watchdog = setTimeout(() => { failure ||= new Error('Encoder finalization timed out'); encoder.kill('SIGKILL'); }, 6000);
    }, 50);
    if (feeder) {
      await Promise.race([feeder, exited]);
      stopping = true;
      if (capture) capture.kill('SIGTERM');
      await feeder;
      encoder.stdin.end();
    }
    const outcome = await exited;
    clearTimeout(watchdog);
    if (failure) throw failure;
    if (outcome.code !== 0 && !(stopping && outcome.code === 255)) throw new Error(`${command} exited ${outcome.code ?? outcome.signal}`);
    if (!existsSync(session.output) || !statSync(session.output).size) throw new Error('Encoder produced no video');
    save(resultPath(session.token), { ok: true, frames: session.target.kind === 'window' ? frames : undefined });
  } catch (e) {
    failure = e;
    console.error(e.message);
    capture?.kill('SIGTERM');
    if (encoder?.pid && encoder.exitCode === null) { encoder.kill('SIGTERM'); await delay(300); if (encoder.exitCode === null) encoder.kill('SIGKILL'); }
    save(resultPath(session.token), { ok: false, error: e.message });
  } finally {
    clearInterval(timer); clearTimeout(watchdog);
    const child = spawn(wrapper, ['_finish', session.token], { detached: true, stdio: 'ignore' });
    child.on('error', () => {}); child.unref();
  }
}

async function main() {
  if (args.includes('--help') || args.includes('-h')) { console.log(help); return; }
  mkdirSync(stateDir, { recursive: true, mode: 0o700 });
  mkdirSync(logDir, { recursive: true, mode: 0o700 });
  if (args[0] === '_worker') { await worker(JSON.parse(args[1])); return; }
  if (args[0] === '_finish') {
    const session = json(stateFile);
    if (session?.token === args[1]) {
      const result = json(resultPath(session.token));
      if (result) finish(session, result);
    }
    return;
  }
  const { command, options } = parse([...args]);
  if (command === 'list') {
    const data = desktop();
    if (options.json) console.log(JSON.stringify(data));
    else {
      for (const m of data.monitors) console.log(`monitor\t${m.name}\t${m.width}x${m.height}\t${m.focused ? 'active' : ''}`);
      for (const w of data.windows) console.log(`window\t${w.address}\t${JSON.stringify(w.class)}\t${JSON.stringify(w.title)}\tworkspace=${w.workspace?.name}`);
    }
    return;
  }
  if (command === 'resolve') { console.log(JSON.stringify(resolveTarget(options))); return; }
  const session = await reconcile();
  if (command === 'is-active') { process.exitCode = alive(session) ? 0 : 1; return; }
  if (command === 'status') {
    if (options.json) console.log(JSON.stringify(session ? sessionStatus(session) : { active: false, last: json(lastFile) }));
    else {
      const elapsed = session ? Math.floor((Date.now() - session.started) / 1000) : 0;
      console.log(JSON.stringify(session ? { text: '●', class: 'recording', tooltip: `Recording ${Math.floor(elapsed / 60)}:${String(elapsed % 60).padStart(2, '0')}` } : { text: '', class: 'idle', tooltip: '' }));
    }
    return;
  }
  if (command === 'stop' || command === 'cancel' || (command === 'toggle' && session)) await stop(session, command === 'cancel', options);
  else await start(options);
}
main().catch(e => { console.error(`screen-record: ${e.message}`); process.exitCode = 1; });
