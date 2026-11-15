-- Four-finger swipe down opens the magic special workspace.
-- Four-finger swipe up closes it.
--
-- The built-in "special" action follows the finger and shows or hides
-- based on whether the workspace is already visible, in either direction.
-- These swipes only commit once the fingers have travelled `commit`
-- units in the bound direction, and only when magic is in the other state.

local commit = 5

local function magicVisible()
	local special = hl.get_active_special_workspace()
	return special ~= nil and special.name == "special:magic"
end

local function directional(wantOpen)
	local distance = 0

	return {
		start = function()
			distance = 0
		end,
		update = function(e)
			-- Down is positive. Opening wants down, closing wants up.
			local delta = wantOpen and e.delta.y or -e.delta.y
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

			if magicVisible() == wantOpen then
				return
			end

			hl.dispatch(hl.dsp.workspace.toggle_special("magic"))
		end,
	}
end

hl.gesture({
	fingers = 4,
	direction = "down",
	action = directional(true),
})

hl.gesture({
	fingers = 4,
	direction = "up",
	action = directional(false),
})
