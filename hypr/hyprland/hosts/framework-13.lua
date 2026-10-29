-- Host-specific Hyprland config for framework-13.
-- Required from hyprland.lua in its own scope, so modifiers are repeated here.

local mainMod = "SUPER"
local menu = "vicinae toggle"

hl.on("hyprland.start", function()
	hl.exec_cmd("kdeconnect-indicator")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("systemctl --user start easyeffects.service")
	hl.exec_cmd("systemctl --user start vicinae.service")
	hl.exec_cmd("aw-watcher-window-hyprland")
end)

-- Opening the lid is not key/mouse activity, so hypridle will not turn the
-- panel back on. Force a modeset; a plain dpms on is a no-op when Hyprland
-- already thinks the panel is on. locked: still runs on hyprlock.
hl.bind(
	"switch:off:Lid Switch",
	hl.dsp.exec_cmd("~/config/scripts/hosts/framework-13/wake-panel.sh"),
	{ locked = true }
)

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("wofi --show run"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("vicinae vicinae://launch/wm/switch-windows"))
