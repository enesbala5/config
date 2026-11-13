// Run: node --test scripts/power/tests/lid-inhibit.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync, statSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL("../lid-inhibit", import.meta.url));
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const bootSeconds = () => Math.floor(Number(readFileSync("/proc/uptime", "utf8").split(" ")[0]));

async function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "lid-"));
  const bin = join(root, "bin");
  const instance = join(root, "hypr", "test");
  const state = join(root, "lid-inhibit");
  const active = join(root, "lid-inhibit.service.active");
  const log = join(root, "calls");
  mkdirSync(bin);
  mkdirSync(instance, { recursive: true });
  mkdirSync(state);
  writeFileSync(join(instance, "hyprland.lock"), `${process.pid}\nwayland-test\n`);
  writeFileSync(log, "");
  const socket = join(instance, ".socket.sock");
  const server = createServer();
  server.listen(socket);
  await once(server, "listening");
  const children = [];
  t.after(async () => {
    for (const child of children) {
      if (child.exitCode === null && child.signalCode === null) {
        const exited = once(child, "exit");
        child.kill("SIGTERM");
        await exited;
      }
    }
    if (server.listening) await new Promise((resolve) => server.close(resolve));
    rmSync(root, { recursive: true, force: true });
  });
  writeFileSync(join(root, "units"), "");
  const mocks = {
    systemctl: `
unit=\${!#}
name=\${unit%.service}
printf '%s\\n' "$unit" >>"$TEST_ROOT/units"
case "$2" in
  is-active) test -f "$TEST_ROOT/$unit.active" ;;
  stop)
    [[ "\${FAIL_STOP:-0}" == 0 ]] || exit 1
    printf 'stop\\n' >>"$TEST_ROOT/calls"
    rm -f "$TEST_ROOT/$unit.active" "$TEST_ROOT/$name/deadline" ;;
  *) exit 2 ;;
esac`,
    "systemd-run": `
printf 'start\\n' >>"$TEST_ROOT/calls"
printf '%s\\n' "$@" >"$TEST_ROOT/arguments"
[[ "\${FAIL_RUN:-0}" == 0 ]] || exit 1
unit=
for arg in "$@"; do
  [[ "$arg" != --unit=* ]] || unit=\${arg#--unit=}
done
[[ -n "$unit" ]] || exit 2
name=\${unit%.service}
printf '%s\\n' "$unit" >>"$TEST_ROOT/units"
mkdir -p "$TEST_ROOT/$name"
touch "$TEST_ROOT/$unit.active"
[[ "\${NO_READY:-0}" == 0 ]] || exit 0
read -r uptime rest </proc/uptime
seconds=\${!#}
deadline=0
((seconds == 0)) || deadline=$((\${uptime%%.*} + seconds))
printf '%s\\n' "$deadline" >"$TEST_ROOT/$name/deadline"`,
    "notify-send": `printf 'notify %s\\n' "$*" >>"$TEST_ROOT/calls"; printf '%s\\n' "$@" >"$TEST_ROOT/notification-arguments"`,
    pkill: `printf 'refresh\\n' >>"$TEST_ROOT/calls"; printf '%s\\n' "$@" >>"$TEST_ROOT/refresh-arguments"`,
    vicinae: `printf '%s\\n' "\${MENU_CHOICE:-}"; exit "\${MENU_EXIT:-0}"`,
  };
  for (const [name, body] of Object.entries(mocks)) {
    writeFileSync(join(bin, name), `#!/usr/bin/env bash\n${body}\n`, { mode: 0o755 });
  }
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, TEST_ROOT: root,
    XDG_RUNTIME_DIR: root, HYPRLAND_INSTANCE_SIGNATURE: "test" };
  const run = (args = [], extra = {}) => spawnSync("bash", [script, ...args], { env: { ...env, ...extra }, encoding: "utf8" });
  const worker = (seconds, pid = process.pid) => {
    const child = spawn("bash", [script, "_hold", socket, String(pid), String(statSync(`/proc/${pid}`).ino), String(seconds)], { env, stdio: "pipe" });
    children.push(child);
    return child;
  };
  const setState = (deadline) => {
    writeFileSync(active, "");
    writeFileSync(join(state, "deadline"), `${deadline}\n`);
  };
  return { root, state, active, log, instance, socket, server, env, run, worker, setState,
    calls: () => readFileSync(log, "utf8"),
    args: () => readFileSync(join(root, "arguments"), "utf8").trim().split("\n") };
}

async function waitFor(predicate) {
  for (let n = 0; n < 100; n++) {
    if (predicate()) return;
    await delay(25);
  }
  assert.fail("Timed out waiting for worker state");
}

test("help needs no session, inactive status is valid hidden JSON", async (t) => {
  const f = await fixture(t);
  assert.equal(f.run(["--help"], { XDG_RUNTIME_DIR: "" }).status, 0);
  assert.deepEqual(JSON.parse(f.run(["status"]).stdout), { text: "", class: "inactive", tooltip: "" });
  assert.equal(f.calls(), "");
});

test("default toggles a single lid-only service for one hour, then stops", async (t) => {
  const f = await fixture(t);
  assert.equal(f.run().status, 0);
  const args = f.args();
  assert.ok(args.includes("--what=handle-lid-switch"));
  assert.ok(args.includes("--unit=lid-inhibit.service"));
  assert.ok(args.includes("--no-ask-password"));
  assert.ok(!args.some((arg) => arg.includes("--what=sleep")));
  assert.equal(args.at(-1), "3600");
  assert.match(JSON.parse(f.run(["status"]).stdout).text, /^LID 60m$/);
  assert.equal(f.run().status, 0);
  assert.equal(existsSync(f.active), false);
  assert.equal(f.calls().split("\n").filter((line) => line === "start").length, 1);
});

test("durations replace existing worker; infinity is explicit", async (t) => {
  const f = await fixture(t);
  for (const [duration, seconds] of [["30m", "1800"], ["2h", "7200"], ["01m", "60"], ["3s", "3"], ["infinity", "0"]]) {
    assert.equal(f.run(["on", duration]).status, 0, duration);
    assert.equal(f.args().at(-1), seconds);
  }
  assert.equal(JSON.parse(f.run(["status"]).stdout).text, "LID ∞");
  assert.match(JSON.parse(f.run(["status"]).stdout).tooltip, /Idle locking and suspend still work/);
});

test("invalid arguments never stop an existing worker", async (t) => {
  const f = await fixture(t);
  f.setState(0);
  for (const args of [["on", "0"], ["on", "-1h"], ["on", "999999h"], ["on", "1.5h"], ["on", "oops"], ["on", "1h", "extra"], ["off", "extra"], ["unknown"]]) {
    assert.notEqual(f.run(args).status, 0, args.join(" "));
    assert.equal(existsSync(f.active), true);
  }
  assert.doesNotMatch(f.calls(), /^stop$/m);
  assert.doesNotMatch(f.calls(), /^start$/m);
});

test("menu choices, Escape and empty selection", async (t) => {
  const f = await fixture(t);
  for (const [choice, seconds] of [["1 hour", "3600"], ["30 minutes", "1800"], ["2 hours", "7200"], ["Until turned off", "0"]]) {
    assert.equal(f.run(["menu"], { MENU_CHOICE: choice }).status, 0);
    assert.equal(f.args().at(-1), seconds);
  }
  const before = f.calls();
  assert.equal(f.run(["menu"], { MENU_EXIT: "1" }).status, 0);
  assert.equal(f.run(["menu"]).status, 0);
  assert.equal(f.calls(), before);
  assert.equal(f.run(["menu"], { MENU_CHOICE: "Restore lid handling" }).status, 0);
  assert.equal(existsSync(f.active), false);
});

test("status hides expired, corrupt and stale state without notifications", async (t) => {
  const f = await fixture(t);
  for (const deadline of [bootSeconds() - 1, "invalid"]) {
    f.setState(deadline);
    assert.equal(JSON.parse(f.run(["status"]).stdout).text, "");
  }
  f.setState(0);
  rmSync(f.active);
  assert.equal(JSON.parse(f.run(["status"]).stdout).text, "");
  assert.equal(f.calls(), "");
});

test("launch failure or failure before readiness never reports success", async (t) => {
  const f = await fixture(t);
  for (const extra of [{ FAIL_RUN: "1" }, { NO_READY: "1" }]) {
    const result = f.run(["on", "1h"], extra);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Could not acquire/);
    assert.equal(JSON.parse(f.run(["status"]).stdout).text, "");
  }
  assert.doesNotMatch(f.calls(), /Lid-close suspension suppressed/);
});

test("missing session fails before replacing an existing inhibitor", async (t) => {
  const f = await fixture(t);
  f.setState(0);
  await new Promise((resolve) => f.server.close(resolve));
  assert.notEqual(f.run(["on", "1h"]).status, 0);
  assert.equal(existsSync(f.active), true);
  assert.doesNotMatch(f.calls(), /^stop$/m);
});

test("launcher without instance environment finds the single compositor", async (t) => {
  const f = await fixture(t);
  assert.equal(f.run(["on", "1h"], { HYPRLAND_INSTANCE_SIGNATURE: "" }).status, 0);
  assert.ok(f.args().includes(f.socket));
});

test("concurrent toggles serialize without duplicate workers", async (t) => {
  const f = await fixture(t);
  const results = await Promise.all(Array.from({ length: 8 }, () => {
    const child = spawn("bash", [script], { env: f.env, stdio: "ignore" });
    return once(child, "exit");
  }));
  assert.ok(results.every(([code]) => code === 0));
  assert.equal(existsSync(f.active), false);
  assert.equal(f.calls().split("\n").filter((line) => line === "start").length, 4);
});

test("worker expires and cleans state", { timeout: 5000 }, async (t) => {
  const f = await fixture(t);
  const child = f.worker(1);
  const exited = once(child, "exit");
  await waitFor(() => existsSync(join(f.state, "deadline")));
  const [code] = await exited;
  assert.equal(code, 0);
  assert.equal(existsSync(join(f.state, "deadline")), false);
});

test("worker releases on socket removal, compositor death and TERM", { timeout: 10000 }, async (t) => {
  const f = await fixture(t);
  const socketWorker = f.worker(0);
  let exited = once(socketWorker, "exit");
  await waitFor(() => existsSync(join(f.state, "deadline")));
  await new Promise((resolve) => f.server.close(resolve));
  assert.equal((await exited)[0], 0);
  assert.equal(existsSync(join(f.state, "deadline")), false);

  f.server.listen(f.socket);
  await once(f.server, "listening");
  const compositor = spawn("sleep", ["30"]);
  const deathWorker = f.worker(0, compositor.pid);
  exited = once(deathWorker, "exit");
  await waitFor(() => existsSync(join(f.state, "deadline")));
  const died = once(compositor, "exit");
  compositor.kill();
  await died;
  assert.equal((await exited)[0], 0);
  assert.equal(existsSync(join(f.state, "deadline")), false);

  const termWorker = f.worker(0);
  exited = once(termWorker, "exit");
  await waitFor(() => existsSync(join(f.state, "deadline")));
  termWorker.kill("SIGTERM");
  assert.equal((await exited)[0], 0);
  assert.equal(existsSync(join(f.state, "deadline")), false);
});

test("only the lid switch is inhibited and Waybar receives signal 12", async (t) => {
  const f = await fixture(t);
  assert.equal(f.run(["on"]).status, 0);
  assert.deepEqual(f.args().filter((arg) => arg.startsWith("--what=")), ["--what=handle-lid-switch"]);
  assert.ok(f.args().includes("--mode=block"));
  assert.ok(f.args().includes("--who=Ignore Lid"));
  const notification = readFileSync(join(f.root, "notification-arguments"), "utf8").trim().split("\n");
  assert.deepEqual(notification.slice(0, 5), ["-a", "Ignore Lid", "-i", "preferences-desktop-screensaver", "Ignore Lid"]);
  assert.equal(notification.length, 6);
  assert.match(notification[5], /Lid-close suspension suppressed/);
  assert.match(readFileSync(join(f.root, "refresh-arguments"), "utf8"), /-RTMIN\+12/);
  const status = JSON.parse(f.run(["status"]).stdout);
  assert.match(status.tooltip, /Do not put the running laptop in a bag/);
  assert.match(status.tooltip, /Expiry or stop with the lid closed may suspend/);
});

test("stop failure preserves the active inhibitor and never claims restoration", async (t) => {
  const f = await fixture(t);
  f.setState(0);
  const result = f.run(["off"], { FAIL_STOP: "1" });
  assert.notEqual(result.status, 0);
  assert.equal(existsSync(f.active), true);
  assert.equal(existsSync(join(f.state, "deadline")), true);
  assert.doesNotMatch(f.calls(), /Normal lid handling restored/);
});

test("control commands never address Caffeinate's service or state", async (t) => {
  const f = await fixture(t);
  const cafState = join(f.root, "caffeinate");
  const cafActive = join(f.root, "caffeinate.service.active");
  mkdirSync(cafState);
  writeFileSync(cafActive, "");
  writeFileSync(join(cafState, "deadline"), "0\n");
  assert.equal(f.run(["on", "30m"]).status, 0);
  assert.equal(f.run(["off"]).status, 0);
  assert.equal(existsSync(cafActive), true);
  assert.equal(readFileSync(join(cafState, "deadline"), "utf8"), "0\n");
  assert.ok(readFileSync(join(f.root, "units"), "utf8").trim().split("\n")
    .every((unit) => unit === "lid-inhibit.service"));
});

test("Caffeinate and Ignore Lid can run together and stop independently", async (t) => {
  const f = await fixture(t);
  const cafScript = fileURLToPath(new URL("../caffeinate", import.meta.url));
  const caf = (args) => spawnSync("bash", [cafScript, ...args], { env: f.env, encoding: "utf8" });
  const cafActive = join(f.root, "caffeinate.service.active");
  assert.equal(caf(["on", "infinity"]).status, 0);
  assert.equal(f.run(["on", "infinity"]).status, 0);
  assert.equal(JSON.parse(caf(["status"]).stdout).text, "CAF ∞");
  assert.equal(JSON.parse(f.run(["status"]).stdout).text, "LID ∞");
  assert.equal(caf(["off"]).status, 0);
  assert.equal(existsSync(cafActive), false);
  assert.equal(existsSync(f.active), true);
  assert.equal(caf(["on", "infinity"]).status, 0);
  assert.equal(f.run(["off"]).status, 0);
  assert.equal(existsSync(cafActive), true);
  assert.equal(existsSync(f.active), false);
  assert.equal(caf(["off"]).status, 0);
});

test("worker cleanup does not remove Caffeinate's state", { timeout: 5000 }, async (t) => {
  const f = await fixture(t);
  const cafState = join(f.root, "caffeinate");
  mkdirSync(cafState);
  writeFileSync(join(cafState, "deadline"), "0\n");
  const child = f.worker(1);
  const exited = once(child, "exit");
  await waitFor(() => existsSync(join(f.state, "deadline")));
  assert.equal((await exited)[0], 0);
  assert.equal(existsSync(join(f.state, "deadline")), false);
  assert.equal(readFileSync(join(cafState, "deadline"), "utf8"), "0\n");
});
