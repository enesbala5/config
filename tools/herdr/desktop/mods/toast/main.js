// Toast content inside Herdr's overlay chrome (host owns border/bg/radius).
// Keep this flat — no second pill. notify({ title, body, level, icon, action }).

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { props, closeOverlay, run, theme } from "herdr";

const TONE = {
  error: "blocked",
  warning: "working",
  success: "done",
  info: "accent",
};

const GLYPH = {
  error: "circle-alert",
  warning: "triangle-alert",
  success: "check",
  info: "info",
};

/** `#rrggbb` or `#rgb` + alpha 0..1 → `#rrggbbaa`. */
function withAlpha(hex, a) {
  const raw = String(hex ?? "#000000").replace(/^#/, "");
  const h =
    raw.length === 3
      ? raw
          .split("")
          .map((c) => c + c)
          .join("")
      : raw.slice(0, 6).padEnd(6, "0");
  const aa = Math.round(Math.min(1, Math.max(0, a)) * 255)
    .toString(16)
    .padStart(2, "0");
  return `#${h}${aa}`;
}

function badge(level, t) {
  const key = TONE[level] ?? "accent";
  const tone = t[key] ?? t.accent;
  const name = GLYPH[level] ?? "info";
  return h_flex()
    .size(32)
    .flex_none()
    .items_center()
    .justify_center()
    .rounded_full()
    .bg(withAlpha(tone, 0.12))
    .child(svg(`mods/toast/${name}.svg`).size(16).flex_none().text_color(tone));
}

export default class Toast extends View {
  render(cx) {
    const t = theme();
    const p = props() ?? {};

    return h_flex()
      .id("toast")
      .size_full()
      .px(12)
      .gap(12)
      .items_center()
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .on_click(() => {
        if (p.action?.name) run(p.action.name, p.action.args ?? {});
        closeOverlay(p.overlay);
      })
      .child(p.icon ? image(p.icon).w(32).h(32).flex_none().rounded(16) : badge(p.level, t))
      .child(
        v_flex()
          .flex_1()
          .min_w(0)
          .overflow_hidden()
          .gap(2)
          .child(
            div()
              .truncate()
              .font_semibold()
              .text_size(13)
              .line_height("20px")
              .text_color(t.foreground)
              .child(p.title ?? ""),
          )
          .when(Boolean(p.body), (el) =>
            el.child(
              div()
                .truncate()
                .text_size(13)
                .line_height("18px")
                .text_color(t.muted)
                .child(p.body ?? ""),
            ),
          ),
      );
  }
}
