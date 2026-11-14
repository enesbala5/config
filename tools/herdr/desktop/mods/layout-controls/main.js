import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, run, props, updates, layout, nextCommand, focused, panes, terminals, shared, setShared, hc } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar shows either Lists (Spaces and Agents) or the Inbox (t3-inbox): a stack in the layout.
const inboxShown = () => find(layout(), "sidebar-lists")?.active === "inbox";
const switchSidebar = () => run("layout.select", { stack: "sidebar-lists", child: inboxShown() ? "lists" : "inbox" });

const SIDE_STORE = "side-pane.by-tab";
const sideByTab = new Map();
// tab -> primary terminal while a split may still be settling
const sideOpening = new Map();

function readStore() {
  const fromShared = shared(SIDE_STORE);
  if (fromShared && typeof fromShared === "object" && !Array.isArray(fromShared)) {
    return { ...fromShared };
  }
  try {
    const raw = JSON.parse(localStorage.getItem(SIDE_STORE) ?? "{}");
    return typeof raw === "object" && raw && !Array.isArray(raw) ? raw : {};
  } catch {
    return {};
  }
}

function writeStore(map) {
  setShared(SIDE_STORE, map);
  try {
    localStorage.setItem(SIDE_STORE, JSON.stringify(map));
  } catch {
    /* ignore */
  }
}

function getEntry(tab) {
  const mem = sideByTab.get(tab);
  if (mem?.primary && mem?.side && mem.primary !== mem.side) return mem;
  const raw = readStore()[tab];
  if (!raw || typeof raw !== "object") return undefined;
  if (!raw.side || !raw.primary || raw.side === raw.primary) return undefined;
  sideByTab.set(tab, raw);
  return raw;
}

function setEntry(tab, primary, side) {
  if (!primary || !side || primary === side) return;
  const entry = { primary, side };
  sideByTab.set(tab, entry);
  const map = readStore();
  map[tab] = entry;
  writeStore(map);
}

function hideSide(side, primary) {
  if (!side || !primary || side === primary) return;
  run("terminal.park", { terminal: side });
  run("pane.focus", { terminal: primary });
}

// Decide which terminal is the side pane to hide/show. Never returns primary as side.
function resolvePair(tab, tabPanes, focusedTerminal) {
  const entry = getEntry(tab);
  if (entry) {
    const sideShown = tabPanes.some((p) => p.terminal === entry.side);
    const primaryShown = tabPanes.some((p) => p.terminal === entry.primary);
    if (sideShown && primaryShown) return entry;
    if (!sideShown && terminals().some((t) => t.address === entry.side)) {
      return { ...entry, restore: true };
    }
  }

  if (tabPanes.length !== 2) return undefined;

  const openingPrimary = sideOpening.get(tab);
  if (openingPrimary && tabPanes.some((p) => p.terminal === openingPrimary)) {
    const side = tabPanes.find((p) => p.terminal !== openingPrimary);
    if (side?.terminal) return { primary: openingPrimary, side: side.terminal };
  }

  if (entry?.primary && tabPanes.some((p) => p.terminal === entry.primary)) {
    const side = tabPanes.find((p) => p.terminal !== entry.primary);
    if (side?.terminal) return { primary: entry.primary, side: side.terminal };
  }

  const focusedPane = tabPanes.find((p) => p.terminal === focusedTerminal) ?? tabPanes[0];
  const other = tabPanes.find((p) => p.terminal !== focusedPane.terminal);
  if (!other) return undefined;

  // Prefer keeping an agent pane as primary when focus is on a plain shell.
  if (focusedPane.status == null && other.status != null) {
    return { primary: other.terminal, side: focusedPane.terminal };
  }
  return { primary: focusedPane.terminal, side: other.terminal };
}

// Ctrl+\ : show/hide a right shell pane; park keeps the process while hidden.
function toggleSide() {
  const f = focused();
  if (!f?.tab || !f.pane || !f.terminal) return;

  const tab = f.tab;
  const tabPanes = panes().filter((p) => p.tab === tab && p.terminal);
  const pair = resolvePair(tab, tabPanes, f.terminal);

  if (pair?.restore) {
    run("terminal.keep", { terminal: pair.side, place: "right" });
    sideOpening.delete(tab);
    return;
  }

  if (pair?.side && pair?.primary && tabPanes.length >= 2) {
    setEntry(tab, pair.primary, pair.side);
    sideOpening.delete(tab);
    hideSide(pair.side, pair.primary);
    return;
  }

  // Open: split right from the focused pane. Hide uses the 2-pane pair above.
  sideOpening.set(tab, f.terminal);
  sideByTab.set(tab, { primary: f.terminal, side: undefined });
  run("pane.split", { direction: "right", pane: f.pane });
}

// Scroll Herdr's history and forward the key to application-owned history (Pi).
async function jumpToBottom() {
  const terminal = focused()?.terminal;
  if (!terminal) return;
  run("terminal.scroll", { terminal, to: "bottom" });
  // Write directly to the PTY: this cannot re-trigger Herdr's key binding.
  const result = await hc(["keys", terminal, "ctrl+alt+down"]);
  if (result.code !== 0) throw new Error(result.stderr || "Could not forward Ctrl+Alt+Down");
}

export default class WorkspaceChrome extends View {
  init(_props, cx) {
    // Only the brand bar's copy takes key commands; the footer's has nothing to switch.
    if (props()?.footer) return;
    cx.spawn(async (cx) => {
      for (;;) {
        const cmd = await nextCommand();
        if (cmd === "sidebar") switchSidebar();
        else if (cmd === "side") toggleSide();
        else if (cmd === "bottom") {
          try { await jumpToBottom(); }
          catch (error) { console.error("Jump to bottom:", error); }
        }
        cx.notify();
      }
    });
  }

  render() {
    const t = theme();
    if (props()?.footer) {
      const row = (id, icon, label, action) => h_flex().id(id).relative().h(30).px(8).gap(8).items_center().rounded(8)
        .role("button").accessibility_label(label)
        .text_color(t.muted).hover(s => s.bg(t.hover).text_color(t.foreground))
        .on_click(action).child(h_flex().size(18).flex_none().items_center().justify_center()
          .child(svg(`mods/layout-controls/${icon}.svg`).size(16)))
        .child(div().flex_1().min_w(0).truncate().child(label));
      return v_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).px(8).pt(4).pb(6).text_size(13)
        .child(h_flex().gap(2).items_center()
          .child(row("settings", "settings", "Settings", () => run("app.settings")).flex_1().min_w(0)
            .when(Boolean(updates().app.ready), el => el.child(div().size(6).rounded_full().bg(t.accent))))
          .child(div().id("add-machine").size(26).flex_none().flex().items_center().justify_center().rounded(6)
            .text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
            .role("button").accessibility_label("Add machine")
            .on_click(() => run("mod.open", { name: "machine-add" }))
            .child(svg("mods/workspace-chrome/server.svg").size(14))));
    }
    // Room for the macOS window buttons (layout traffic_lights), a place to drag the window, and the
    // sidebar toggle at its right edge; while the sidebar is hidden, t3-tabs shows it after the buttons.
    const inbox = inboxShown();
    return h_flex().id("brand").size_full().bg(t.chrome).pr(10).gap(2).items_center().justify_end()
      .child(div().id("sidebar-mode").size(26).flex_none().flex().items_center().justify_center().rounded(6)
        .text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
        .role("button").accessibility_label(inbox ? "Show lists" : "Show inbox")
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click(switchSidebar)
        .child(svg(`mods/workspace-chrome/${inbox ? "layers" : "circle-check"}.svg`).size(14)))
      .child(div().id("sidebar-toggle").size(26).flex_none().flex().items_center().justify_center().rounded(6)
        .text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
        .role("button").accessibility_label("Hide sidebar")
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click(() => run("layout.toggle", { id: "sidebar" }))
        .child(svg("mods/workspace-chrome/sidebar.svg").size(14)));
  }
}
