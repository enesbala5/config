-- Touchpad gestures. Required from hyprland.lua as `require("modules.gestures")`.

hl.config({
	gestures = {
		workspace_swipe_distance = 300,
		workspace_swipe_cancel_ratio = 0.1,
		-- The default `m` selector skips workspaces without windows. `r` walks
		-- neighbouring IDs instead, so the four-finger swipe reaches empty
		-- desktops just like Super+CTRL+left/right. Keep create_new on so the
		-- 1:1 swipe can also follow the finger into a workspace not opened yet.
		workspace_swipe_use_r = true,
		workspace_swipe_create_new = true,
	},
})

require("modules.gestures.workspace_swipe")
require("modules.gestures.window_focus_swipe")
require("modules.gestures.special_workspace_swipe")
require("modules.gestures.fullscreen_swipe")
