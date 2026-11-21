import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, panes, agents, terminals, run, openOverlay, theme, window, layout, settings } from "herdr";
import { namer } from "./name.js";
import { ownStatus, subAgents, treeStatus } from "./tree.js";

// With the inbox showing (t3-inbox), an agent settled there isn't news: its done is left out.
// One that works or gets stuck is unsettled there, so only done needs leaving out.
function awake() {
  if (find(layout(), "sidebar-lists")?.active !== "inbox") return agents();
  const put = new Set(terminals().filter((k) => k.labels?.settled).map((k) => k.address));
  return agents().filter((a) => !put.has(a.address));
}

// "Needs you", drawn as the agents list and pane headers draw it.
const blockedMark = (t) => div().size(14).flex_none().rounded(4).bg(t.blocked + "26").text_size(11).font_bold().text_color(t.blocked).flex().items_center().justify_center().child("!");
const mark = (t, s) => s === "working" ? svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)
  : s === "blocked" ? blockedMark(t)
  : div().size(7).flex_none().rounded_full().bg(t.done);

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class Tabs extends View {
  init() {
    this.pressed = null;
  }

  // With the sidebar hidden, its toggle also says how the agents are doing, with the sidebar's own marks.
  // Idle agents aren't counted: nothing to look at.
  sidebarToggle(t, stop, live, st) {
    const counts = ["blocked", "working", "done"].map(s => [s, live.filter(a => st(a) === s).length]).filter(([, n]) => n > 0);
    const words = { blocked: "need you", working: "working", done: "done" };
    const summary = counts.map(([s, n]) => `${n} ${words[s]}`).join(" · ");
    return h_flex().id("sidebar-toggle").h(26).px(6).gap(8).flex_none().items_center().rounded(6)
      .text_size(12).text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
      .role("button").accessibility_label(summary ? `Show sidebar, ${summary}` : "Show sidebar")
      .on_mouse_down("left", stop).on_click(() => run("layout.toggle", { id: "sidebar" }))
      .child(svg("mods/workspace-chrome/sidebar.svg").size(14).flex_none())
      .children(counts.map(([s, n]) => h_flex().id(`agents-${s}`).gap(4).items_center().child(mark(t, s)).child(div().text_color(t.muted).child(String(n)))));
  }

  render() {
    const t = theme();
    const space = spaces().find(p => p.active);
    const shown = space?.tabs ?? [];
    const live = awake();
    // Each agent with its sub-agents (tree.js).
    const every = agents(), all = terminals(), under = subAgents(every, all);
    const st = (a) => treeStatus(ownStatus(a.status, a.address, all), under(a.address));
    const ps = panes(), title = namer();
    const stop = (_e, cx) => cx.stop_propagation();
    const button = (id, label, action) => div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click(action).child(label);
    const item = (c, i) => {
      // A tab nobody named reads as its lead pane: the agent in it, else the focused one.
      const mine = ps.filter(p => p.tab === c.id);
      const lead = mine.find(p => p.status != null) ?? mine.find(p => p.focused) ?? mine[0];
      const program = lead?.program;
      const name = c.named ? c.name : lead ? title(lead) : "Terminal";
      // The tab's most urgent agent, ranked as the app ranks tabs; a done one only while it's still news.
      const words = every.filter(a => a.tab === c.id).map(st);
      const status = words.includes("blocked") ? "blocked"
        : live.some(a => a.tab === c.id && st(a) === "done") ? "done"
        : words.includes("working") ? "working" : null;
      return h_flex().id(`tab-${c.id}`).h(28).px(8).gap(8).rounded(6).items_center().flex_none().text_size(13)
        .bg(c.active ? t.selected : t.chrome).text_color(c.active ? t.foreground : t.muted)
        .when(!c.active, el => el.hover(s => s.bg(t.hover)))
        .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); this.pressed = i; if (e.click_count === 2) run("tab.rename", { id: c.id }); })
        .on_mouse_up("left", () => {
          const from = this.pressed; this.pressed = null;
          if (from !== null && from !== i) run("tab.move", { id: shown[from].id, index: space.tabs.findIndex(x => x.id === c.id) + 1 });
          else run("tab.select", { id: c.id });
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: "menu", kind: "popup", width: 200, props: { tab: "tab", target: { id: c.id, space: space.id } } }); })
        .when(Boolean(program?.icon), el => el.child(program.tint ? svg(program.icon).size(14).text_color(t.muted) : image(program.icon).size(14)))
        .child(div().max_w(170).truncate().child(c.zoomed ? `${name} Z` : name))
        .when(status != null, el => el.child(mark(t, status)))
        .when(c.active, el => el.child(div().id(`close-${c.id}`).text_color(t.dim).on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: c.id }); }).child(svg("mods/pane/close.svg").size(12))));
    };
    const root = layout(), sidebar = find(root, "sidebar"), w = window();
    // Old saved rails and a dragged-narrow sidebar can be smaller than the window buttons.
    const lightsPadding = w?.platform === "macos" && w.titlebar === "none" && !w.fullscreen && root?.traffic_lights
      ? Math.max(8, (root.traffic_lights[0] + 64) / settings().zoom - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0))
      : 8;
    return h_flex().size_full().min_w(0).px(8).pl(lightsPadding).gap(4).items_center().bg(t.chrome)
      .on_mouse_up("left", () => { this.pressed = null; })
      .on_scroll_wheel(e => { if (Math.abs(e.delta.y) >= 1) run(e.delta.y > 0 ? "tab.prev" : "tab.next"); })
      .when(Boolean(sidebar?.hidden), el => el.child(this.sidebarToggle(t, stop, live, st)))
      .child(h_flex().id("tab-scroll").flex_1().min_w(0).h_full().items_center().gap(4).overflow_x_scroll().children(shown.map(item)))
      .child(button("tab-new", svg("mods/workspace-chrome/plus.svg").size(14), () => run("tab.new")))
      .when(w?.buttons, el => el.child(button("minimize", w.platform === "windows" ? svg("mods/t3-tabs/win-min.svg").size(16) : "−", () => run("window.minimize")))
        .child(button("maximize", w.platform === "windows" ? svg(`mods/t3-tabs/${w.maximized ? "win-restore" : "win-max"}.svg`).size(16) : "□", () => run("window.maximize")))
        .child(button("close-window", w.platform === "windows" ? svg("mods/t3-tabs/win-close.svg").size(16) : svg("mods/pane/close.svg").size(13), () => run("window.close"))));
  }
}
