-- Autostart. Required from hyprland.lua as `require("modules.autostart")`.

hl.on("hyprland.start", function()
	hl.exec_cmd("sh -c '> ~/.config/hypr/monitors.lua' && hyprdynamicmonitors run")
	hl.exec_cmd("waybar")
	hl.exec_cmd("waypaper --restore")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("hyprlock --no-fade-in")
	hl.exec_cmd("keymapper -c ~/config/tools/keymapper/configuration.conf --no-tray")
	hl.exec_cmd("nm-applet --indicator")
end)
