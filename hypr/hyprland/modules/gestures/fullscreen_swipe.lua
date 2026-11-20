-- Three-finger vertical swipe toggles true fullscreen for the focused window.
-- Swipe up enters fullscreen; swipe down leaves it.
--
-- These swipes only commit once the fingers have travelled `commit` units in
-- the bound direction, and only when the window is not already in the target
-- state. That keeps repeated swipes in the same direction from toggling back
-- out, and avoids dispatching with no window focused.

local commit = 5

local function directional(wantFullscreen)
	local distance = 0

	return {
		start = function()
			distance = 0
		end,
		update = function(e)
			-- Down is positive. Entering wants up, leaving wants down.
			local delta = wantFullscreen and -e.delta.y or e.delta.y
			if delta > 0 then
				distance = distance + delta
			end
		end,
		finish = function(e)
			local travelled = distance
			distance = 0

			if e.cancelled or travelled < commit then
				return
			end

			local active = hl.get_active_window()
			if not active then
				return
			end

			local fullscreen = (active.fullscreen or 0) ~= 0
			if fullscreen == wantFullscreen then
				return
			end

			hl.dispatch(hl.dsp.window.fullscreen())
		end,
	}
end

hl.gesture({
	fingers = 3,
	direction = "up",
	action = directional(true),
})

hl.gesture({
	fingers = 3,
	direction = "down",
	action = directional(false),
})
