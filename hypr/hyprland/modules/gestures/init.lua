-- Touchpad gestures. Required from hyprland.lua as `require("modules.gestures")`.

hl.config({
	gestures = {
		workspace_swipe_distance = 300,
		workspace_swipe_cancel_ratio = 0.1,
	},
})

require("modules.gestures.workspace_swipe")
require("modules.gestures.window_focus_swipe")
