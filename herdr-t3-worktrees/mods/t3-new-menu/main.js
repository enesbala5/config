// New: pick the space (or a new one) and open a terminal tab there.
import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex, InputState, Input } from "gpui-base";
import { theme, spaces, panes, run, closeOverlay, props, window, keys, shared, home } from "herdr";

function shortcut(name) {
  const k = keys().find(b => b.section === "global" && b.action === name);
  if (!k?.keys.trim()) return "";
  const mac = window()?.platform === "macos";
  const names = mac ? { ctrl: "⌃", alt: "⌥", shift: "⇧", cmd: "⌘", fn: "fn" } : { ctrl: "Ctrl", alt: "Alt", shift: "Shift", cmd: "Super", fn: "Fn" };
  const alias = { secondary: mac ? "cmd" : "ctrl", super: "cmd", win: "cmd" };
  return k.keys.trim().split(/\s+/).map(stroke => {
    const parts = stroke.split("-");
    let key = parts.pop();
    if (key === "") { key = "-"; parts.pop(); }
    const held = new Set(parts.map(m => alias[m.toLowerCase()] ?? m.toLowerCase()));
    if (/^[A-Z]$/.test(key)) held.add("shift");
    const label = key.length === 1 ? key.toUpperCase() : key[0].toUpperCase() + key.slice(1).toLowerCase();
    return [...Object.keys(names).filter(m => held.has(m)).map(m => names[m]), label].join(mac ? "" : "+");
  }).join(" ");
}

// Space avatars and where a space is now, as t3-spaces draws and says them.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
const NEW = { id: "new", name: "New space" };

export default class NewMenu extends View {
  init() {
    this.at = 0;
    this.filter = "";
    this.input = InputState.new({ placeholder: "Search spaces…" });
    this.input.on("change", (_e, cx) => { this.filter = this.input.value(); this.at = 0; cx.notify(); });
    this.input.on("submit", () => { this.choose(this.items()[this.at]); });
    this.input.focus();
  }

  items() {
    const ps = panes(), cur = spaces().find(s => s.active), q = this.filter.toLowerCase();
    return [cur, NEW, ...spaces().filter(s => s.id !== cur?.id)].filter(Boolean)
      .filter(s => `${s.name} ${s === NEW ? "" : place(s, ps)}`.toLowerCase().includes(q));
  }

  choose(s) {
    if (!s) return;
    closeOverlay(props().overlay);
    if (s === NEW) run("space.new");
    else run("tab.new", { space: s.id });
  }

  row(id, i, icon, name, sub, hint, pick) {
    const t = theme(), on = this.at === i;
    return h_flex().id(id).h(sub ? 46 : 34).px(10).gap(10).rounded(8).items_center().flex_none()
      .when(on, el => el.bg(t.selected))
      .on_hover((over, cx) => { if (over && this.at !== i) { this.at = i; cx.notify(); } })
      .on_click(pick)
      .child(h_flex().size(20).flex_none().items_center().justify_center().child(icon))
      .child(v_flex().flex_1().min_w(0)
        .child(div().truncate().text_color(t.foreground).child(name))
        .when(Boolean(sub), el => el.child(div().truncate().text_size(11.5).text_color(t.dim).child(sub))))
      .child(div().flex_none().text_size(11).text_color(t.dim).child(hint));
  }

  render() {
    const t = theme(), ps = panes(), h = home();
    const short = (p) => (p && h && p.startsWith(h) ? "~" + p.slice(h.length) : p ?? "");
    const colors = shared("space.colors") ?? {};
    const items = this.items();
    // ⌘1… go by space number, New space aside.
    const bySpace = items.filter(s => s !== NEW);
    let n = 0;
    const rows = items.map((s, i) => {
      if (s === NEW) return this.row("space-new", i, svg("mods/workspace-chrome/folder-plus.svg").size(16).text_color(t.muted), "New space", null, shortcut("space.new"), () => this.choose(NEW));
      const color = colors[s.id] ?? "ansi6", fill = color.startsWith("#") ? color : MARK[color] ?? t[color];
      const num = ++n;
      return this.row(`space-${s.id}`, i,
        h_flex().size(18).rounded(5).bg(fill).items_center().justify_center().text_size(11).font_bold().text_color("#ffffff").child([...s.name][0]?.toUpperCase() ?? "?"),
        s.name, `${s.machine ?? "Local"} · ${short(place(s, ps))}`, num <= 9 ? `⌘${num}` : "", () => this.choose(s));
    });
    return v_flex().id("new-menu").size_full().min_h(0).p(8).gap(4).bg(t.popover).text_size(13)
      .on_key_down((e, cx) => {
        if (e.key === "escape") return closeOverlay(props().overlay);
        if (e.key === "down") this.at = (this.at + 1) % items.length;
        else if (e.key === "up") this.at = (this.at + items.length - 1) % items.length;
        else if (/^[1-9]$/.test(e.key) && e.modifiers.platform) { cx.stop_propagation(); return this.choose(bySpace[Number(e.key) - 1]); }
        else return;
        cx.stop_propagation();
        cx.notify();
      })
      .child(h_flex().h(36).flex_none().px(10).gap(8).items_center()
        .child(svg("mods/workspace-chrome/search.svg").size(14).text_color(t.dim))
        .child(Input.new(this.input).flex_1().h_full().text_size(13).text_color(t.foreground)))
      .child(div().px(10).pt(4).pb(2).text_size(11).text_color(t.dim).child("Spaces"))
      .child(v_flex().id("new-spaces").flex_1().min_h(0).overflow_y_scroll().children(rows));
  }
}
