#!/usr/bin/env node
"use strict";
// Agent Head: leading state glyph + tab title as ONE sidebar token.
//
// Why one token: Herdr's sidebar separator is hardcoded
// (src/ui/sidebar/tokens.rs). Adjacent tokens are joined with " · ", except a
// single space after the built-in state_icon. A custom token therefore cannot
// sit flush against the tab title. Emitting the glyph and the title as a single
// custom token sidesteps the separator entirely.
//
// The trade-off is colour: one token has one style, so a per-state fg tints the
// title too. Drop the `rules` from ui.sidebar.agents.rows if you want a neutral
// title; the glyph shape still distinguishes states.
//
// Everything is display-only metadata via the public surface:
//   herdr pane report-metadata <pane> --source local.agent-head --token head=…
// If this daemon dies, --ttl-ms expires every token it set.

const { spawn, spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const HERDR = process.env.HERDR_BIN_PATH || process.env.HERDR_BIN || "herdr";
const SOURCE = "local.agent-head";
const TOKEN = "head";

const DEFAULTS = {
  // Braille ring: every frame is one cell, so rows never jitter.
  frames: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
  staticGlyphs: { idle: "○", done: "✓", blocked: "×", unknown: "·" },
  fallbackGlyph: "◐",
  // 160ms = 6.25fps. Each frame is one report-metadata call per pane.
  intervalMs: 160,
  // How often to re-read agent state and tab labels.
  pollMs: 1000,
  // Use terminal title / agent name when a tab has no label.
  labelFallback: true,
  enabled: true,
};

function readConfig() {
  try {
    const dir = process.env.HERDR_PLUGIN_CONFIG_DIR;
    if (!dir) return {};
    return JSON.parse(fs.readFileSync(path.join(dir, "config.json"), "utf8"));
  } catch {
    return {};
  }
}

function snapshot() {
  const r = spawnSync(HERDR, ["api", "snapshot"], { encoding: "utf8", timeout: 4000 });
  if (r.status !== 0 || !r.stdout) return null;
  try {
    return JSON.parse(r.stdout).result.snapshot;
  } catch {
    return null;
  }
}

function report(paneId, args) {
  // Detached + ignored stdio: a slow socket must never stall the frame loop.
  const p = spawn(HERDR, ["pane", "report-metadata", paneId, "--source", SOURCE, ...args], {
    stdio: "ignore",
  });
  p.on("error", () => {});
}

let cfg;
let TTL_MS;
let panes = new Map(); // pane_id -> { label, status }
let tick = 0;
let stopping = false;

function poll() {
  if (stopping) return;
  const snap = snapshot();
  if (snap === null) return; // transient socket failure: keep the last known set
  const tabs = new Map((snap.tabs || []).map((t) => [t.tab_id, t.label]));
  const next = new Map();
  for (const agent of snap.agents || []) {
    if (!agent.pane_id) continue;
    let label = tabs.get(agent.tab_id);
    if (!label && cfg.labelFallback) {
      label =
        agent.terminal_title_stripped ||
        agent.terminal_title ||
        agent.display_agent ||
        agent.agent ||
        "";
    }
    next.set(agent.pane_id, { label: String(label || ""), status: agent.agent_status });
  }
  for (const id of panes.keys()) {
    if (!next.has(id)) report(id, ["--clear-token", TOKEN]);
  }
  panes = next;
}

function staticGlyph(status) {
  return cfg.staticGlyphs[status] || cfg.fallbackGlyph;
}

function frame() {
  if (stopping || panes.size === 0) return;
  const moving = cfg.frames[tick++ % cfg.frames.length];
  for (const [id, info] of panes) {
    const glyph = info.status === "working" ? moving : staticGlyph(info.status);
    const value = info.label ? `${glyph} ${info.label}` : glyph;
    report(id, ["--token", `${TOKEN}=${value}`, "--ttl-ms", String(TTL_MS)]);
  }
}

function shutdown() {
  if (stopping) return;
  stopping = true;
  for (const id of panes.keys()) report(id, ["--clear-token", TOKEN]);
  // Give the clear calls a moment to reach the socket before we exit.
  setTimeout(() => process.exit(0), 200);
}

function main() {
  cfg = { ...DEFAULTS, ...readConfig() };
  TTL_MS = Math.max(1000, cfg.intervalMs * 8);
  if (!cfg.enabled) process.exit(0);
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) process.on(sig, shutdown);
  process.on("exit", () => {
    for (const id of panes.keys()) report(id, ["--clear-token", TOKEN]);
  });
  poll();
  setInterval(poll, cfg.pollMs);
  setInterval(frame, cfg.intervalMs);
}

main();
