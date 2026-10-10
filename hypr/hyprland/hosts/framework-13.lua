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

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("wofi --show run"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("vicinae vicinae://launch/wm/switch-windows"))
