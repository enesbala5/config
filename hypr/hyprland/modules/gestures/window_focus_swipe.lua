-- Three-finger horizontal swipe steps focus through the tiled windows on the
-- current workspace in visual order (left to right, then top to bottom),
-- clamped at both ends - it never wraps around. Hyprland's own movefocus falls
-- back to other windows at the edge, which is why this is done explicitly.

local function focusWindowBySwipe(direction)
	local active = hl.get_active_window()
	if not active then
		return
	end

	local windows = {}
	for _, w in ipairs(hl.get_workspace_windows(active.workspace)) do
		if not w.floating then
			windows[#windows + 1] = w
		end
	end

	table.sort(windows, function(a, b)
		if a.at.x ~= b.at.x then
			return a.at.x < b.at.x
		end
		if a.at.y ~= b.at.y then
			return a.at.y < b.at.y
		end
		return a.stable_id < b.stable_id
	end)

	local index
	for i, w in ipairs(windows) do
		if w.address == active.address then
			index = i
			break
		end
	end
	if not index then
		return
	end

	local target = windows[index + (direction == "right" and 1 or -1)]
	if not target then
		return
	end

	hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address }))
	hl.dispatch(hl.dsp.window.bring_to_top())
end

-- Switch focus every `step` units of finger travel instead of once per gesture.
-- delta.x is relative motion: right is positive, left is negative.
local step = 150
local distance = 0

local windowSwipeAction = {
	start = function()
		distance = 0
	end,
	update = function(e)
		distance = distance + e.delta.x

		while math.abs(distance) >= step do
			local left = distance < 0

			distance = distance + (left and step or -step)
			focusWindowBySwipe(left and "left" or "right")
		end
	end,
	finish = function()
		distance = 0
	end,
}

hl.gesture({
	fingers = 3,
	direction = "left",
	action = windowSwipeAction,
})

hl.gesture({
	fingers = 3,
	direction = "right",
	action = windowSwipeAction,
})
