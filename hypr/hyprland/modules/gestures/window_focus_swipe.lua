-- Three-finger horizontal drag continuously steps through tiled windows.
-- Freeze the window order for the entire gesture: fullscreen focus transfers
-- rewrite geometry, so re-sorting after each step can bounce between windows.
local step = 180
local distance = 0
local swipe

local function beginSwipe()
	distance = 0
	swipe = nil

	local active = hl.get_active_window()
	if not active or active.floating or not active.workspace then
		return
	end

	local workspace = active.workspace
	local windows = {}
	local stableOrder = workspace.tiled_layout == "monocle"
	for _, w in ipairs(hl.get_workspace_windows(workspace)) do
		if w.mapped and not w.floating then
			-- Copy values, not live window objects whose geometry can change.
			windows[#windows + 1] = {
				address = w.address,
				id = w.stable_id,
				x = w.at.x,
				y = w.at.y,
			}
			stableOrder = stableOrder or (w.fullscreen or 0) ~= 0
		end
	end

	table.sort(windows, function(a, b)
		if not stableOrder then
			if a.x ~= b.x then
				return a.x < b.x
			end
			if a.y ~= b.y then
				return a.y < b.y
			end
		end
		return a.id < b.id
	end)

	for i, w in ipairs(windows) do
		if w.address == active.address then
			swipe = {
				windows = windows,
				index = i,
				workspace = workspace.id,
				monocle = workspace.tiled_layout == "monocle",
			}
			break
		end
	end
end

local windowSwipeAction = {
	start = beginSwipe,
	update = function(e)
		if not swipe or #swipe.windows < 2 then
			return
		end

		local active = hl.get_active_window()
		if not active or not active.workspace or active.workspace.id ~= swipe.workspace then
			-- Never continue a stale drag on another workspace.
			swipe = nil
			return
		end

		distance = distance + e.delta.x
		if (swipe.index == 1 and distance < 0)
			or (swipe.index == #swipe.windows and distance > 0) then
			distance = 0
			return
		end

		local steps = math.floor(math.abs(distance) / step)
		if steps == 0 then
			return
		end

		local direction = distance < 0 and -1 or 1
		distance = distance - direction * steps * step

		local requestedIndex = swipe.index + direction * steps
		local index = math.max(1, math.min(#swipe.windows, requestedIndex))
		if index ~= requestedIndex or index == 1 or index == #swipe.windows then
			-- Discard overscroll at either edge, including partial steps, so
			-- reversing responds without first undoing the excess travel.
			distance = 0
		end
		if index == swipe.index then
			return
		end

		if swipe.monocle then
			-- Native cycling reveals monocle's transparent/input-blocked target,
			-- but wraps by default. Limit it to the remaining windows so a long
			-- drag cannot endlessly cycle the same windows.
			local command = direction > 0 and "cyclenext" or "cycleprev"
			local count = math.abs(index - swipe.index)
			swipe.index = index
			for _ = 1, count do
				hl.dispatch(hl.dsp.layout(command))
			end
			return
		end

		local target = hl.get_window("address:" .. swipe.windows[index].address)
		if not target or not target.mapped or target.floating or not target.workspace
			or target.workspace.id ~= swipe.workspace then
			-- A window closed or moved mid-drag; wait for a fresh snapshot.
			swipe = nil
			return
		end

		swipe.index = index
		-- One dispatch per event, even if a large delta crosses several steps.
		-- Focus handles fullscreen transfer; do not raise the window again.
		hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address }))
	end,
	finish = function()
		distance = 0
		swipe = nil
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
