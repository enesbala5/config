import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { agents, terminals, panes, focused, spaces, run, theme, shared, setShared, setAgentOrder, openOverlay, closeOverlay, props, window, layout, exec } from "herdr";

const GLYPH = { pi: "π" };
function sessionTitle(title, prog, space) {
  const names = [prog?.key, prog?.name, GLYPH[prog?.key]].filter(Boolean).map((n) => n.toLowerCase());
  const ws = String(space ?? "").toLowerCase();
  let t = String(title ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();
  const SEP = /^(.+?)\s*(?:[·・‧|»]\s*|:\s+|\s[-—–]\s+)(.+)$/;
  for (let i = 0; i < 3; i++) {
    const m = t.match(SEP);
    if (!m) break;
    const head = m[1].trim().toLowerCase();
    if (!names.some((n) => head === n || n.startsWith(head)) && head !== ws) break;
    t = m[2].trim();
  }
  t = t.replace(/^π\s*/u, "");
  for (let i = 0; i < 3; i++) {
    const m = t.match(/^(.*?)(?:\s*[·・‧|»]\s*|\s+[-—–]\s+)([^·・‧|»—–]*)$/);
    if (!m) break;
    const tail = m[2].trim().toLowerCase();
    if (tail !== ws && !/^[~/]|^[a-z]:\\/i.test(tail)) break;
    t = m[1].trim();
  }
  if (!t || names.includes(t.toLowerCase()) || /^[~/]|^[A-Za-z]:\\/.test(t) || t.includes("@")) return null;
  return t;
}

const wtTag = (t, name) => h_flex().flex_none().max_w(90).gap(3).items_center().text_size(11).text_color(t.dim)
  .child(svg("mods/workspace-chrome/branch.svg").size(11).flex_none())
  .child(div().truncate().child(name));

function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((t) => t.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

function toggleSidebar() {
  const width = find(layout(), "sidebar")?.size?.px;
  if (!narrow()) setShared("sidebar.width", width);
  setShared("sidebar.collapsed", !narrow());
  run("layout.resize", { id: "sidebar", px: narrow() ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
}

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

function lead(tab, all = panes()) {
  const mine = all.filter(p => p.tab === tab.id && p.terminal);
  return mine.find(p => p.program?.agent) ?? mine.find(p => p.focused) ?? mine[0];
}

function title(tab, l) {
  const prog = l?.program?.name;
  const live = clean(l?.title);
  const telling = live && live !== prog && !/^[~/]|^[A-Za-z]:\\/.test(live) && !live.includes("@") && live.toLowerCase() !== l?.program?.key;
  return tab.name === prog && telling ? live : tab.name;
}
const RANK = { blocked: 4, done: 3, working: 2, idle: 1 };
const kidStatus = (k, listed) => {
  const s = listed.get(k.address) ?? k.status;
  return s === "error" ? "blocked" : s === "done" ? "idle" : s;
};
const SORTS = [
  { id: "priority", label: "Priority", icon: "clock" },
  { id: "grouped", label: "Grouped by space", icon: "layers" },
];
const sortOf = () => SORTS.find((s) => s.id === shared("agents.sort")) ?? SORTS[0];
const SECTION = { 4: "Needs you", 3: "Done", 2: "Working", 1: "Idle" };
const SECTION_STATUS = { 4: "blocked", 3: "done", 2: "working" };

function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).w(size).h(size).flex_none();
}

export default class Agents extends View {
  init(_props, cx) {
    if (props()?.sortMenu) return;
    this.folded = new Set();
    this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}");
    // Let the Go to picker show the same state age, rather than starting a new clock.
    setShared("agents.changed", this.changed);
    this.pins = JSON.parse(localStorage.getItem("pins") ?? "[]");
    this.git = {};
    this.asking = new Set();
    cx.timer.every(30000, (cx) => cx.notify());
  }

  gitOf(folder, machine, cx) {
    const key = JSON.stringify([machine ?? null, folder]);
    if (key in this.git || this.asking.has(key)) return this.git[key] ?? null;
    this.asking.add(key);
    cx.spawn(async (cx) => {
      try {
        const r = await exec("git", ["rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir"], { cwd: folder, on: machine });
        const [dir, repo] = r.stdout.trim().split(/\r?\n/);
        this.git[key] = r.code === 0 && repo ? { repo: JSON.stringify([machine ?? null, repo]), linked: repo !== `${dir}/.git`, name: dir.split("/").pop() } : null;
      } catch {
        this.git[key] = null;
      }
      this.asking.delete(key);
      cx.notify();
    });
    return null;
  }

  homes(cx) {
    const ps = panes();
    const sp = spaces().map((s) => ({ s, g: place(s, ps) ? this.gitOf(place(s, ps), s.machine, cx) : null }));
    const main = {};
    for (const r of sp) if (r.g && !r.g.linked) main[r.g.repo] ??= r.s;
    return new Map(sp.map((r) => [r.s.id, (r.g?.linked && main[r.g.repo]) || r.s]));
  }

  track(list, now) {
    let dirty = false;
    for (const a of list) {
      const s = a.status === "done" ? "idle" : a.status;
      if (this.changed[a.address]?.s === s) continue;
      this.changed[a.address] = { s, at: now };
      dirty = true;
    }
    if (!dirty) return;
    const listed = new Set(list.map((a) => a.address));
    for (const [k, c] of Object.entries(this.changed)) if (!listed.has(k) && now - c.at > 30 * 86400000) delete this.changed[k];
    localStorage.setItem("changed", JSON.stringify(this.changed));
    setShared("agents.changed", this.changed);
  }

  setPins(pins) {
    this.pins = pins;
    localStorage.setItem("pins", JSON.stringify(pins));
  }

  prunePins(all) {
    const machine = (addr) => (addr.includes("/") ? addr.split("/")[0] : "");
    const heard = new Set(all.map((k) => machine(k.address)));
    const live = new Set(all.filter((k) => k.state === "live").map((k) => k.address));
    const kept = this.pins.filter((p) => !heard.has(machine(p)) || live.has(p));
    if (kept.length !== this.pins.length) this.setPins(kept);
  }

  since(a) {
    return this.changed[a.address]?.at ?? 0;
  }

  hold(list) {
    const cur = list.find((a) => a.focused);
    const same = cur && cur.address === this.held?.address;
    if (!same || cur.status !== "idle") this.held = cur ? { address: cur.address, rank: RANK[cur.status] ?? 0 } : null;
  }

  rank(a) {
    const sawDone = a.address === this.held?.address && this.held.rank === RANK.done && a.status === "idle";
    return sawDone ? RANK.done : RANK[a.status] ?? 0;
  }

  sortMenu(t) {
    const on = sortOf().id;
    return v_flex()
      .w_full()
      .p(5)
      .bg(t.popover)
      .text_size(12.8)
      .child(div().px(8).pt(4).pb(6).text_size(11).text_color(t.dim).child("Sort agents"))
      .children(SORTS.map((s) => h_flex()
        .id(`sort-${s.id}`)
        .h(31)
        .px(8)
        .gap(9)
        .rounded(7)
        .items_center()
        .text_color(t.foreground)
        .hover((el) => el.bg(t.hover))
        .on_click(() => {
          setShared("agents.sort", s.id);
          closeOverlay(props().overlay);
        })
        .child(svg(`mods/workspace-chrome/${s.icon}.svg`).size(14).flex_none().text_color(t.muted))
        .child(div().flex_1().child(s.label))
        .when(s.id === on, (el) => el.child(svg("mods/workspace-chrome/check.svg").size(14).flex_none().text_color(t.foreground)))));
  }

  peek(addr) {
    run("terminal.peek", { terminal: addr });
  }

  tree(all, addr, lead = []) {
    const kids = all.filter((k) => k.parent === addr && k.state === "live");
    return kids.flatMap((k, i) => {
      const last = i === kids.length - 1;
      return [
        { t: k, lines: [...lead, last ? "└" : "├"] },
        ...this.tree(all, k.address, [...lead, last ? "" : "│"]),
      ];
    });
  }

  subRow(t, s, shown, compact, cx) {
    const k = s.t;
    const g = k.cwd ? this.gitOf(k.cwd, k.address.includes("/") ? k.address.split("/")[0] : null, cx) : null;
    const wt = g?.linked ? g.name : null;
    const st = kidStatus(k, this.listed);
    const pic = icon(k.program, 14, t.foreground);
    const on = k.address === shown;
    return h_flex()
      .id(`sub-${k.address}`)
      .pl(39)
      .pr(8)
      .rounded(8)
      .h(26)
      .flex_none()
      .gap(0)
      .items_center()
      .text_size(12.5)
      .when(on, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.hover))
      .on_click(() => this.peek(k.address))
      .children(s.lines.map(l => div().self_start().mt(-4).w(9).h(17).mr(4).flex_none()
        .when(Boolean(l), el => el.border_l(1.5).border_color(t.input))
        .when(l === "└" || l === "├", el => el.border_b(1.5).rounded_bl(6))))
      .when(Boolean(pic), el => el.child(div().mr(8).child(pic)))
      .child(div().flex_1().truncate().text_color(on ? t.foreground : t.muted).child(k.name || k.template || k.program?.name || k.address))
      .when(Boolean(wt), el => el.child(wtTag(t, wt).mr(8)))
      .child(this.status(t, { status: st }, compact));
  }

  status(t, a, compact = false) {
    const color = t[a.status] ?? t.dim;
    if (a.status === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).mx(1).flex_none().text_color(t.working).spin(900);
    if (a.status === "blocked" && compact) return div().size(14).flex_none().rounded(4).bg(t.blocked + "26").text_size(10.5).font_bold().text_color(t.blocked).flex().items_center().justify_center().child("!");
    if (a.status === "blocked") return div().flex_none().px(6).h(18).rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).flex().items_center().child("Needs you");
    if (a.status === "idle") return div().size(7).mx(3).flex_none().rounded(4).border(1.5).border_color(t.idle ?? t.dim);
    return div().size(7).mx(3).flex_none().rounded(4).bg(a.status === "done" ? color : t.dim + "00");
  }

  render(cx) {
    const t = theme();
    if (props()?.sortMenu) return this.sortMenu(t);
    const collapsed = narrow();
    const sort = sortOf();
    let list = agents();
    this.listed = new Map(list.map((a) => [a.address, a.status]));
    const all = terminals();
    const shown = focused()?.agent;
    const now = Date.now();
    this.track(list, now);
    this.hold(list);
    const byPriority = sort.id === "priority";
    const urgency = new Map(list.map((a) => [a.address, Math.max(this.rank(a), ...this.tree(all, a.address).map((s) => RANK[kidStatus(s.t, this.listed)] ?? 0))]));
    const rankOf = (a) => urgency.get(a.address);
    const home = this.homes(cx);
    const homeOf = (a) => home.get(a.space) ?? { id: a.space, name: a.space_name };
    const spaceAt = new Map(spaces().map((s, i) => [s.id, i]));
    if (byPriority) list = [...list].sort((x, y) => rankOf(y) - rankOf(x) || this.since(y) - this.since(x) || y.seq - x.seq);
    else list = [...list].sort((x, y) => (spaceAt.get(homeOf(x).id) ?? 0) - (spaceAt.get(homeOf(y).id) ?? 0));
    this.prunePins(all);
    const pinned = this.pins.map((p) => list.find((a) => a.address === p)).filter(Boolean);
    const rest = list.filter((a) => !this.pins.includes(a.address));
    list = [...pinned, ...rest];
    setAgentOrder(list.map((a) => a.address));

    const withKids = (a, i, extra = [], line = null) => {
      const subs = collapsed ? [] : this.tree(all, a.address, line ? [line === "└" ? "" : "│"] : []);
      const r = row(a, i, subs, line);
      let kids = this.folded.has(a.address) ? [] : subs;
      if (extra.length) kids = kids.map((s) => ({ ...s, lines: s.lines.map((l, n) => (n ? l : l === "└" ? "├" : l === "" ? "│" : l)) }));
      return [
        r,
        ...kids.map((s) => this.subRow(t, s, shown, byPriority, cx)),
        ...extra.flatMap((w, n) => withKids(w, i, [], n === extra.length - 1 ? "└" : "├")),
      ];
    };

    const fold = (a, subs) => {
      const sts = subs.map((s) => kidStatus(s.t, this.listed));
      const top = sts.reduce((m, s) => ((RANK[s] ?? 0) > (RANK[m] ?? 0) ? s : m), null);
      const open = !this.folded.has(a.address);
      return div()
        .id(`fold-${a.address}`)
        .h(18)
        .px(3)
        .gap(3)
        .flex()
        .items_center()
        .rounded(4)
        .text_size(11)
        .text_color(open ? t.dim : (t[top] ?? t.dim))
        .cursor_pointer()
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click((_e, cx) => {
          cx.stop_propagation();
          open ? this.folded.add(a.address) : this.folded.delete(a.address);
          cx.notify();
        })
        .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(11).flex_none())
        .when(!open, (el) => el.child(String(subs.length)));
    };

    const tabs = spaces().flatMap(s => s.tabs);
    const label = (a) => {
      const tab = tabs.find(tab => tab.id === a.tab);
      return tab ? title(tab, lead(tab)) : a.title || a.program?.name || "";
    };
    const detail = new Map(list.map(a => {
      const tab = tabs.find(tab => tab.id === a.tab);
      const own = tab?.named ? tab.name : sessionTitle(a.title, a.program, a.space_name);
      return [a.address, own ?? (/^\d+$/.test(label(a)) ? null : label(a))];
    }));
    const seen = {};
    for (const a of list) { const k = `${a.space_name}\u0000${detail.get(a.address) ?? ""}`; seen[k] = (seen[k] ?? 0) + 1; }
    for (const a of list) {
      if (detail.get(a.address) == null && seen[`${a.space_name}\u0000`] > 1) detail.set(a.address, label(a));
    }

    const row = (a, i, subs = [], line = null) => {
      const pic = icon(a.program, 15, t.foreground);
      const more = detail.get(a.address);
      const machine = a.address.includes("/") ? a.address.split("/")[0] : null;
      if (collapsed) {
        return h_flex()
          .id(`ag-${a.address}`)
          .h(26)
          .px(8)
          .flex_none()
          .items_center()
          .gap(4)
          .hover((s) => s.bg(t.hover))
          .on_click(() => run("pane.focus", { pane: a.pane }))
          .child(div().flex_1().min_w(0).whitespace_nowrap().text_right().text_color(t.muted).child(String(i + 1)))
          .child(h_flex().w(14).flex_none().items_center().justify_center().child(this.status(t, a, true)));
      }
      const when = this.since(a);
      const idle = a.status === "idle" && !a.focused;
      const isPinned = this.pins.includes(a.address);
      const pin = div()
        .id(`pin-${a.address}`)
        .flex_none()
        .p(2)
        .rounded(4)
        .text_color(t.dim)
        .cursor_pointer()
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .tooltip(isPinned ? "Unpin" : "Pin to the top")
        .on_click((_e, cx) => {
          cx.stop_propagation();
          this.setPins(isPinned ? this.pins.filter((p) => p !== a.address) : [...this.pins, a.address]);
          this.hovered = null;
          cx.notify();
        })
        .child(svg(`mods/workspace-chrome/${isPinned ? "pin-off" : "pin"}.svg`).size(13));
      // Two rows like the TUI: title + time/status, then workspace · worktree.
      const titleText = more ?? (/^\d+$/.test(label(a)) ? a.program?.name || label(a) : label(a));
      const home = homeOf(a);
      const isWt = home.id !== a.space;
      const workspace = (isWt ? home.name : a.space_name) || "";
      const worktree = isWt ? a.space_name : null;
      const meta = Boolean(workspace) || Boolean(worktree);
      return h_flex()
        .id(`ag-${a.address}`)
        .px(8)
        .py(6)
        .when(Boolean(line), (el) => el.pl(39))
        .flex_none()
        .rounded(8)
        .items_start()
        .gap(9)
        .when(Boolean(line), (el) => el.child(div().self_start().mt(2).w(9).h(17).mr(-5).flex_none().border_l(1.5).border_color(t.input).border_b(1.5).rounded_bl(6)))
        .when(a.focused, (el) => el.bg(t.selected))
        .cursor_pointer()
        .hover((s) => s.bg(t.hover))
        .on_hover((on, cx) => {
          if (on) this.hovered = a.address;
          else if (this.hovered === a.address) this.hovered = null;
          cx.notify();
        })
        .on_click(() => run("pane.focus", { pane: a.pane }))
        .when(Boolean(pic), el => el.child(h_flex().id(`agent-fold-${a.address}`).mt(3.5).size(15).flex_none().items_center().justify_center()
          .when(subs.length > 0, el => el.on_click((_e, cx) => {
            cx.stop_propagation();
            this.folded.has(a.address) ? this.folded.delete(a.address) : this.folded.add(a.address);
            cx.notify();
          })).child(pic)))
        .child(v_flex().flex_1().min_w(0).gap(2)
          .child(h_flex().w_full().min_w(0).gap(6).items_center()
            .child(div().flex_1().min_w(0).truncate().text_color(idle ? t.muted : t.foreground).child(titleText || a.program?.name || ""))
            .when(Boolean(machine), el => el.child(div().text_size(10).text_color(t.dim).child(machine)))
            .when(subs.length > 0, el => el.child(fold(a, subs)))
            .when(this.hovered === a.address, el => el.child(pin))
            .when(this.hovered !== a.address && Boolean(when), el => el.child(div().flex_none().text_size(11).text_color(t.dim).child(duration(now - when))))
            .child(this.status(t, a, byPriority && !isPinned)))
          .when(meta, el => el.child(h_flex().min_w(0).gap(4).items_center().text_size(11).text_color(t.dim)
            .when(Boolean(workspace), e => e.child(div().min_w(0).truncate().child(workspace)))
            .when(Boolean(workspace) && Boolean(worktree), e => e.child(div().flex_none().child("\u00b7")))
            .when(Boolean(worktree), e => e.child(wtTag(t, worktree))))));
    };

    const groups = pinned.length ? [{ id: "pinned", label: "Pinned", status: null, members: pinned }] : [];
    for (const a of rest) {
      const r = rankOf(a) || RANK.idle;
      const id = byPriority ? `sec-${r}` : `sp-${homeOf(a).id}`;
      if (groups.at(-1)?.id === id) groups.at(-1).members.push(a);
      else groups.push({ id, label: byPriority ? SECTION[r] : homeOf(a).name || "", status: byPriority ? SECTION_STATUS[r] : null, members: [a] });
    }

    const header = (g) => {
      const open = !this.folded.has(g.id);
      const top = g.members.reduce((m, a) => ((RANK[a.status] ?? 0) > (RANK[m] ?? 0) ? a.status : m), null);
      return h_flex()
        .id(g.id)
        .px(8)
        .pt(8)
        .h(30)
        .flex_none()
        .gap(6)
        .items_center()
        .text_size(11)
        .font_medium()
        .cursor_pointer()
        .hover((s) => s.text_color(t.foreground))
        .on_click((_e, cx) => {
          open ? this.folded.add(g.id) : this.folded.delete(g.id);
          cx.notify();
        })
        .child(div().truncate().text_color(t[g.status] ?? t.dim).child(g.label))
        .when(byPriority || !open, (el) => el.child(div().text_color(t.dim).child(String(g.members.length))))
        .child(div().flex_1())
        .when(!open, (el) => el
          .when(!byPriority && top && top !== "idle", (el) => el.child(this.status(t, { status: top }, true)))
          .child(svg("mods/workspace-chrome/chevron-right.svg").size(11).flex_none().text_color(t.dim)));
    };
    const groupRows = (g) => {
      const own = g.members.filter((a) => byPriority || homeOf(a).id === a.space);
      const wts = g.members.filter((a) => !own.includes(a));
      if (!own.length || !wts.length) return g.members.flatMap((a, i) => withKids(a, i));
      return [...own.slice(0, -1).flatMap((a, i) => withKids(a, i)), ...withKids(own.at(-1), own.length - 1, wts)];
    };
    const rows = collapsed
      ? list.flatMap((a, i) => withKids(a, i))
      : groups.flatMap((g) => [header(g), ...(this.folded.has(g.id) ? [] : groupRows(g))]);

    return v_flex()
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .text_size(13)
      .when(!collapsed, (el) =>
        el.child(
          h_flex()
            .px(16)
            .h(41)
            .pt(14)
            .pb(5)
            .flex_none()
            .items_center()
            .justify_between()
            .child(div().text_size(11.5).font_medium().text_color(t.dim).child("Agents"))
            .child(
              div()
                .id("ag-sort")
                .text_size(11)
                .text_color(t.dim)
                .hover((s) => s.text_color(t.foreground))
                .on_click(() => openOverlay({ mod: "agents-list", kind: "popup", width: 200, height: 140, props: { sortMenu: true } }))
                .tooltip(`Sort agents: ${sort.label}`)
                .child(svg(`mods/workspace-chrome/${sort.icon}.svg`).size(14)),
            ),
        ),
      )
      .when(list.length === 0 && !collapsed, (el) =>
        el.child(div().px(12).text_size(12).text_color(t.dim).child("No agent status yet. Agents show up here when they report their status. Older versions and agents inside tmux may not.")),
      )
      .child(v_flex().id("ag-list").flex_1().min_h(0).px(collapsed ? 0 : 8).overflow_y_scrollbar().mode("always").children(rows))
      .when(collapsed, (el) =>
        el.child(
          h_flex()
            .h(28)
            .items_center()
            .justify_center()
            .child(
              div()
                .id("collapse")
                .text_size(13)
                .text_color(t.dim)
                .hover((s) => s.text_color(t.foreground))
                .on_click(toggleSidebar)
                .child("»"),
            ),
        ),
      );
  }
}
