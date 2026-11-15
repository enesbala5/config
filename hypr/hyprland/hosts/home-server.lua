-- Host-specific Hyprland config for home-server.

local mainMod = "SUPER"

hl.on("hyprland.start", function()
	hl.exec_cmd("blueman-applet")
end)

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("wofi --show run"))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("wofi --show run"))
