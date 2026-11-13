-- Four-finger horizontal swipe moves through workspaces.
--
-- Built-in workspace swipe calls Monitor::changeWorkspace directly, so it
-- skips binds:hide_special_on_workspace_change and leaves magic stuck on top.
-- Clear any active special when the destination workspace becomes active.

local function hideActiveSpecial()
	local special = hl.get_active_special_workspace()
	if not special or special.name == "" then
		return
	end

	local name = special.name:match("^special:(.+)$") or special.name
	hl.dispatch(hl.dsp.workspace.toggle_special(name))
end

hl.on("workspace.active", function()
	hideActiveSpecial()
end)

hl.gesture({
	fingers = 4,
	direction = "horizontal",
	action = "workspace",
})
