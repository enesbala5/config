-- Three-finger swipe up enters true fullscreen for the focused window.
-- Swipe down restores the window from fullscreen or maximized.
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

			-- Mark this as a deliberate toggle so the animation module can
			-- re-enable geometry animations immediately on the way out. Focus
			-- takeovers from the horizontal swipe do not set this, and keep
			-- their flicker-free suppression.
			hl.explicit_fullscreen_toggle = wantFullscreen
			if wantFullscreen then
				hl.dispatch(hl.dsp.window.fullscreen())
			else
				-- Toggling true fullscreen on a maximized window would enter it.
				hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set" }))
			end
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
