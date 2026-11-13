-- Windows and workspaces. Required from hyprland.lua as `require("modules.windows")`.

-- Workspace 1 is a fullscreen stack: all windows are laid out at full size,
-- so Alt+Tab/cyclenext swaps windows without a resize.
hl.workspace_rule({ workspace = "1", layout = "monocle" })

-- Anonymous on purpose. Named rules run first, so a named base rule would beat
-- the later anonymous profile overrides.

hl.window_rule({ match = { class = "kitty" }, opacity = "1 override 0.95 override 1 override" })
hl.window_rule({ match = { class = "org.kde.dolphin" }, opacity = "0.85 override 0.80 override 0.85 override" })
hl.window_rule({ match = { class = "thunar" }, opacity = "0.85 override 0.80 override 0.85 override" })
hl.window_rule({ match = { title = ".*Developer Tools.*" }, opacity = "0.9 override 0.85 override 0.98 override" })
hl.window_rule({ match = { title = ".*DevTools.*" }, opacity = "0.9 override 0.85 override 0.98 override" })

hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

hl.window_rule({
	match = { title = "(Picture-in-Picture)" },
	float = true,
	no_initial_focus = true,
	size = { "324", "181" },
	move = { "(monitor_w - 329)", "(monitor_h - 212)" },
	pin = true,
	animation = "slide right",
})

hl.window_rule({
	match = { title = "(Picture in picture)" },
	float = true,
	no_initial_focus = true,
	size = { "324", "181" },
	move = { "(monitor_w - 329)", "(monitor_h - 212)" },
	pin = true,
	animation = "slide right",
})

hl.window_rule({
	match = { class = "(org.gnome.Calculator)" },
	float = true,
	size = { "450", "704" },
	center = true,
})

hl.window_rule({
	match = { class = "(Proton Pass)" },
	float = true,
	size = { "1120", "740" },
	center = true,
})

hl.window_rule({
	match = { class = "waypaper" },
	float = true,
	size = { "monitor_w * 0.5", "monitor_h * 0.6" },
	center = true,
})

hl.window_rule({
	match = { class = "org.gnome.seahorse.Application" },
	float = true,
	size = { "1120", "740" },
	center = true,
})

hl.window_rule({
	match = { class = "\\.blueman-manager-wrapped" },
	float = true,
	size = { "1120", "740" },
	center = true,
})

hl.window_rule({ match = { class = "(Cursor)$" }, center = true })
hl.window_rule({ match = { class = "(Code)$" }, center = true })
hl.window_rule({ match = { class = "(dev.zed.Zed-Nightly)$" }, center = true })
hl.window_rule({ match = { title = "(Zed — Settings)" }, float = true })

hl.window_rule({
	match = { class = "org.freedesktop.impl.portal.desktop.kde" },
	center = true,
	size = { "monitor_w * 0.6", "monitor_h * 0.55" },
	float = true,
})

hl.window_rule({ match = { class = "^(affinity.exe)" }, tile = true })

hl.window_rule({ match = { title = "(Developer Tools)" }, tile = true })
hl.window_rule({ match = { title = "(DevTools)" }, tile = true })

hl.window_rule({ match = { initial_title = "^(Wage Visualizer)" }, tile = true })
hl.window_rule({ match = { initial_class = "^(.qemu-system-x86_64-wrapped)" }, fullscreen = true })

hl.layer_rule({ match = { namespace = "zen" }, blur = true })
hl.layer_rule({ match = { namespace = "org.kde.dolphin" }, blur = true })
hl.layer_rule({ match = { namespace = "thunar" }, blur = true })

hl.layer_rule({
	match = { namespace = "vicinae" },
	blur = true,
	blur_popups = true,
	ignore_alpha = 0,
	dim_around = true,
	no_anim = true,
})

hl.layer_rule({
	match = { namespace = "chrome" },
	blur = true,
	ignore_alpha = 0,
	dim_around = true,
})

hl.layer_rule({
	match = { namespace = "^(affinity.exe)" },
	blur = true,
	ignore_alpha = 0,
	dim_around = true,
})

hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })

hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
