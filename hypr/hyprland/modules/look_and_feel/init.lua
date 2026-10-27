-- Look and feel. Required from hyprland.lua as `require("modules.look_and_feel")`.

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
			color = "rgba(1a1a1aee)",
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
})

hl.curve("windows-in-bezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "windows-in-bezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })

-- No crossfade when switching fullscreen windows. Other fade* leaves still inherit fade.
hl.animation({ leaf = "fadeIn", enabled = false })
hl.animation({ leaf = "fadeSwitch", enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "default" })
