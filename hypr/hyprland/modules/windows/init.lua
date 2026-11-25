-- Windows and workspaces. Required from hyprland.lua as `require("modules.windows")`.

-- Workspace 1 is a fullscreen stack: all windows are laid out at full size,
-- so Alt+Tab/cyclenext swaps windows without a resize.
hl.workspace_rule({ workspace = "1", layout = "monocle" })

-- Playwright drives Helium over CDP and creates its pages at about:blank.
-- Match that initial title so windows the human opens from the CLI or Vicinae
-- (New Tab / a real site) keep their normal placement.
hl.window_rule({
	name = "playwright-windows-staging",
	match = { class = "helium", initial_title = "^about:blank" },
	workspace = "11",
})

local function playwright_empty_workspace(win)
	local occupied = {}
	for _, ws in ipairs(hl.get_workspaces()) do
		if ws.id >= 11 and ws.windows > 0 then
			for _, w in ipairs(hl.get_workspace_windows(ws)) do
				if w.address ~= win.address then
					occupied[ws.id] = true
					break
				end
			end
		end
	end
	for id = 11, 99 do
		if not occupied[id] then
			return id
		end
	end
	return nil
end

hl.on("window.open", function(win)
	if win.class ~= "helium" or not win.initial_title:match("^about:blank") then
		return
	end
	local target = playwright_empty_workspace(win)
	if not target or (win.workspace and win.workspace.id == target) then
		return
	end
	-- v0.56 needs a tick before dispatching a move from window.open.
	hl.timer(function()
		hl.dispatch(hl.dsp.window.move({ window = win, workspace = target }))
	end, { timeout = 1, type = "oneshot" })
end)

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

-- OpenScreen's recording HUD is a frameless overlay: no border, no blur behind
-- it, pinned on every workspace and parked just above the bar. Match its title
-- so the editor window ("OpenScreen") keeps its normal placement/decorations.
hl.window_rule({
	match = { class = "(openscreen)", title = "^openscreen$" },
	float = true,
	pin = true,
	border_size = 0,
	move = { "(monitor_w - window_w) / 2", "monitor_h - window_h - 31" },
	no_blur = true,
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
