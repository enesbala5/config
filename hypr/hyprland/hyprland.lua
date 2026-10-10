-- Hyprland config. https://wiki.hypr.land/Configuring/Start/
--
-- monitors.lua (hyprdynamicmonitors) is required last so its window rules
-- override the defaults below (DevTools tile vs float).

local terminal = "kitty"
local helium = "helium --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1 --remote-allow-origins=*"
local textEditor = "obsidian"
local fileManager = "dolphin"
local fileManagerSecondary = "thunar"
local clipboardManager = "vicinae vicinae://launch/clipboard/history"
local clipboardManagerBackup = "cliphist list | vicinae dmenu --placeholder \"Select option\" | cliphist decode | wl-copy"
local codeEditor = "zeditor"
local menu = "vicinae toggle"
local emojiPicker = "vicinae vicinae://launch/core/search-emojis"
local mainMod = "SUPER"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("sh -c '> ~/.config/hypr/monitors.lua' && hyprdynamicmonitors run")
	hl.exec_cmd("waybar")
	hl.exec_cmd("waypaper --restore")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("hyprlock --no-fade-in")
	hl.exec_cmd("keymapper -c ~/config/tools/keymapper/configuration.conf --no-tray")
	hl.exec_cmd("nm-applet --indicator")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "12")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- The old experimental.xx_color_management_v4 flag is the default color pipeline now.
hl.config({
	xwayland = {
		force_zero_scaling = true,
	},

	general = {
		gaps_in = 5,
		border_size = 2,
		col = {
			active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 0,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},
		blur = {
			enabled = true,
			size = 2,
			passes = 3,
			new_optimizations = true,
			popups = true,
			popups_ignorealpha = 1,
		},
	},

	dwindle = {
		preserve_split = true,
	},

	master = {
		new_status = "master",
	},

	misc = {
		force_default_wallpaper = 1,
		disable_hyprland_logo = true,
		mouse_move_focuses_monitor = false,
		-- 1 = "take_over": focusing another window (e.g. Alt+Tab/cyclenext) while a
		-- window is fullscreen/maximized hands the same mode to the new window
		-- instead of dropping out of fullscreen (2, the default). 0 = ignore.
		on_focus_under_fullscreen = 1,
	},

	cursor = {
		no_warps = true,
	},

	debug = {
		disable_logs = false,
		vfr = false,
	},

	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = -0.1,
		force_no_accel = true,
		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.25,
		},
	},

	gestures = {
		workspace_swipe_distance = 300,
		workspace_swipe_cancel_ratio = 0.1,
	},
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })
-- No crossfade when switching fullscreen windows. Other fade* leaves still inherit fade.
hl.animation({ leaf = "fadeIn", enabled = false })
hl.animation({ leaf = "fadeSwitch", enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "default" })

hl.gesture({
	fingers = 4,
	direction = "horizontal",
	action = "workspace",
})

hl.device({
	name = "logitech-g203-prodigy-gaming-mouse",
	sensitivity = -1,
})

---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(codeEditor))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(helium))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + CTRL + SHIFT + B", hl.dsp.exec_cmd("hyprdynamicmonitors run"))
hl.bind(mainMod .. " + CTRL + SHIFT + L", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(
	mainMod .. " + CTRL + SHIFT + M",
	hl.dsp.exec_cmd("kitty zsh -c '~/config/scripts/utilities/clear-monitor-config.sh; zsh -i'", {
		float = true,
		size = { "monitor_w * 0.9", "monitor_h * 0.8" },
		move = { "monitor_w * 0.05", "monitor_h * 0.1" },
	})
)
hl.bind(
	mainMod .. " + CTRL + ESCAPE",
	hl.dsp.exec_cmd("kitty btop", {
		float = true,
		size = { "monitor_w * 0.9", "monitor_h * 0.8" },
		move = { "monitor_w * 0.05", "monitor_h * 0.1" },
	})
)
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("dunstctl close"))

hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("~/config/scripts/audio/handy-bt-toggle.sh"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("~/config/scripts/audio/toggle_sink.sh"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("~/config/scripts/utilities/cancel.sh"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("~/config/scripts/audio/hypr-piper-speak.sh -l en"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("~/config/scripts/audio/hypr-piper-speak.sh"))

hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("pidof hyprlock --no-fade-in || hyprlock"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManagerSecondary))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(textEditor))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("vicinae vicinae://launch/@dagimg-dot/store.vicinae.player-pilot/player-pilot"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("~/config/scripts/music/play-pause.sh"))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/config/scripts/utilities/screenshot.sh"))
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("~/config/scripts/utilities/screen-record.sh"))
hl.bind(mainMod .. " + CTRL + SHIFT + D", hl.dsp.exec_cmd("~/config/scripts/utilities/dnd-toggle.sh"))
hl.bind(mainMod .. " + CTRL + SHIFT + I", hl.dsp.exec_cmd("~/config/scripts/utilities/color-picker.sh"))

hl.bind(mainMod .. " + F", hl.dsp.window.float())
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin())
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("vicinae vicinae://launch/system/run"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("wofi -show run"))
hl.bind(mainMod .. " + D", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + CTRL + ALT + SHIFT + left", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + ALT + SHIFT + right", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(mainMod .. " + CTRL + ALT + SHIFT + up", hl.dsp.workspace.move({ monitor = "u" }))
hl.bind(mainMod .. " + CTRL + ALT + SHIFT + down", hl.dsp.workspace.move({ monitor = "d" }))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brillo -U 5 -e -u 150000"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brillo -A 5 -e -u 150000"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/config/scripts/audio/volume.sh up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/config/scripts/audio/volume.sh down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("~/config/scripts/audio/volume.sh mute"))
hl.bind("XF86AudioMedia", hl.dsp.exec_cmd("~/config/scripts/utilities/toggle-polarity.sh"))

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(clipboardManager))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(clipboardManagerBackup))
hl.bind(mainMod .. " + Period", hl.dsp.exec_cmd(emojiPicker))

hl.bind("ALT + TAB", hl.dsp.window.cycle_next({ tiled = true }))
hl.bind("ALT + TAB", hl.dsp.window.bring_to_top())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false, tiled = true }))
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.bring_to_top())

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + CTRL + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))

hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(mainMod .. " + CTRL + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + CTRL + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + CTRL + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + CTRL + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + CTRL + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + CTRL + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + CTRL + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + CTRL + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + CTRL + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + CTRL + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind("CTRL + SHIFT + F6", hl.dsp.workspace.toggle_special("magic"))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

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

-- Generated by hyprdynamicmonitors. Missing file must not abort the rest.
pcall(require, "monitors")
require("host")
