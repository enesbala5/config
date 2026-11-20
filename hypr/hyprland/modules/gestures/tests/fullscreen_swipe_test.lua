-- Run from repository root: lua hypr/hyprland/modules/gestures/tests/fullscreen_swipe_test.lua
local gestures, dispatched, toggles, active

hl = {
	get_active_window = function() return active end,
	gesture = function(spec) gestures[#gestures + 1] = spec end,
	dispatch = function(command)
		dispatched[#dispatched + 1] = command
		toggles[#toggles + 1] = hl.explicit_fullscreen_toggle
		-- Mirrors Hyprland toggling the focused window's fullscreen state.
		if active then
			active.fullscreen = (active.fullscreen or 0) == 0 and 1 or 0
		end
	end,
	dsp = {
		window = {
			fullscreen = function() return "fullscreen" end,
		},
	},
}

local function window(fullscreen)
	return { fullscreen = fullscreen or 0 }
end

local function reset(win)
	gestures, dispatched, toggles, active = {}, {}, {}, win
	hl.explicit_fullscreen_toggle = nil
	dofile("hypr/hyprland/modules/gestures/fullscreen_swipe.lua")
	assert(#gestures == 2)
	assert(gestures[1].fingers == 3 and gestures[2].fingers == 3)
	assert(gestures[1].direction == "up" and gestures[2].direction == "down")
	return gestures[1].action, gestures[2].action
end

local function expect(...)
	local expected = { ... }
	assert(#dispatched == #expected, "unexpected dispatch count: " .. #dispatched)
	for i, command in ipairs(expected) do
		assert(dispatched[i] == command, "unexpected command: " .. tostring(dispatched[i]))
	end
end

local function swipe(action, delta, cancelled)
	action.start()
	action.update({ delta = { y = delta } })
	action.finish({ cancelled = cancelled or false })
end

-- Swipe up enters fullscreen; repeating it is a no-op.
local up, down = reset(window(0))
swipe(up, -50)
expect("fullscreen")
assert(active.fullscreen ~= 0)
assert(toggles[1] == true, "up must flag an entering toggle")
swipe(up, -50)
expect("fullscreen")
assert(#toggles == 1, "no-op swipe must not flag a toggle")

-- Swipe down leaves fullscreen; repeating it is a no-op.
up, down = reset(window(2))
swipe(down, 50)
expect("fullscreen")
assert(active.fullscreen == 0)
assert(toggles[1] == false, "down must flag a leaving toggle")
swipe(down, 50)
expect("fullscreen")
assert(#toggles == 1, "no-op swipe must not flag a toggle")

-- Sub-threshold and cancelled swipes are ignored.
up, down = reset(window(0))
swipe(up, -3)
swipe(up, -50, true)
expect()
assert(active.fullscreen == 0)

-- Motion in the wrong direction never commits.
up, down = reset(window(0))
swipe(up, 50)
swipe(down, -50)
expect()

-- Motion accumulates across events before release.
up, down = reset(window(0))
up.start()
up.update({ delta = { y = -3 } })
up.update({ delta = { y = -3 } })
up.finish({ cancelled = false })
expect("fullscreen")

-- No focused window is safe.
up, down = reset(nil)
swipe(up, -50)
swipe(down, 50)
expect()

print("fullscreen_swipe: all tests passed")
