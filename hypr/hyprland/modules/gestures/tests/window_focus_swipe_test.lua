-- Run from repository root: lua hypr/hyprland/modules/gestures/tests/window_focus_swipe_test.lua
local gestures, dispatched, active, windows
hl = {
	get_active_window = function() return active end,
	get_workspace_windows = function() return windows end,
	get_window = function(selector)
		for _, w in ipairs(windows) do
			if "address:" .. w.address == selector then return w end
		end
	end,
	gesture = function(spec) gestures[#gestures + 1] = spec end,
	dispatch = function(command)
		dispatched[#dispatched + 1] = command
		-- Simulate focus transfer changing both geometry and fullscreen state.
		local target = hl.get_window(command)
		if target then
			target.fullscreen, active.fullscreen = active.fullscreen, 0
			active.at.x, target.at.x = target.at.x, active.at.x
			active = target
		end
	end,
	dsp = {
		focus = function(spec) return spec.window end,
		layout = function(command) return "layout:" .. command end,
	},
}
local function window(id, x, fullscreen)
	return {
		address = tostring(id), stable_id = id, at = { x = x, y = 0 },
		mapped = true, floating = false, fullscreen = fullscreen or 0,
		workspace = { id = 2, tiled_layout = "dwindle" },
	}
end
local function reset(list, focused)
	gestures, dispatched, windows, active = {}, {}, list, focused
	dofile("hypr/hyprland/modules/gestures/window_focus_swipe.lua")
	assert(#gestures == 2 and gestures[1].action == gestures[2].action)
	local action = gestures[1].action
	action.start()
	return action
end
local function move(action, delta) action.update({ delta = { x = delta } }) end
local function expect(...)
	local expected = { ... }
	assert(#dispatched == #expected, "unexpected dispatch count: " .. #dispatched)
	for i, command in ipairs(expected) do
		assert(dispatched[i] == command, "unexpected command: " .. tostring(dispatched[i]))
	end
end

-- Continuous drag and direction reversal use the original visual order,
-- even though focus changes mutate live window positions.
local a, b, c = window(3, 0), window(1, 100), window(2, 200)
local action = reset({ c, b, a }, a)
move(action, 150)
move(action, 150)
move(action, -150)
move(action, -150)
expect("address:1", "address:2", "address:1", "address:3")

-- Fullscreen and maximized transfers cannot reorder the current gesture.
for _, mode in ipairs({ 1, 2 }) do
	a, b, c = window(1, 100, mode), window(2, 0), window(3, 200)
	action = reset({ c, b, a }, a)
	move(action, 150)
	move(action, 150)
	move(action, -150)
	expect("address:2", "address:3", "address:2")
	-- A new gesture keeps the same stable ordering after fullscreen transfer.
	action.finish()
	action.start()
	move(action, -150)
	expect("address:2", "address:3", "address:2", "address:1")
end

-- A large event selects the final target, without flashing intermediate ones.
a, b, c = window(1, 0), window(2, 100), window(3, 200)
action = reset({ a, b, c }, a)
move(action, 600)
expect("address:3")
move(action, 900)
move(action, -150)
expect("address:3", "address:2")

-- Motion accumulates, but finishing discards sub-threshold motion.
a, b = window(1, 0), window(2, 100)
action = reset({ a, b }, a)
move(action, 80)
move(action, 70)
expect("address:2")
action.finish()
action.start()
move(action, -100)
action.finish()
action.start()
move(action, -100)
expect("address:2")

-- Monocle reveals targets natively but must not wrap during a long drag.
a, b = window(1, 0), window(2, 0)
a.workspace.tiled_layout = "monocle"
action = reset({ a, b }, a)
move(action, 150)
for _ = 1, 100 do move(action, 150) end
expect("layout:cyclenext")
move(action, -150)
for _ = 1, 100 do move(action, -150) end
expect("layout:cyclenext", "layout:cycleprev")
move(action, 150)
expect("layout:cyclenext", "layout:cycleprev", "layout:cyclenext")

-- Huge events are bounded too; partial overscroll cannot delay reversing.
c = window(3, 0)
action = reset({ a, b, c }, a)
move(action, 15000)
expect("layout:cyclenext", "layout:cyclenext")
move(action, 149)
move(action, -150)
expect("layout:cyclenext", "layout:cyclenext", "layout:cycleprev")
move(action, -15000)
expect("layout:cyclenext", "layout:cyclenext", "layout:cycleprev", "layout:cycleprev")
action = reset({ a }, a)
move(action, 600)
expect()

-- Closed targets and workspace changes cancel the stale drag.
a, b = window(1, 0), window(2, 100)
action = reset({ a, b }, a)
b.mapped = false
move(action, 150)
expect()
b.mapped = true
action = reset({ a, b }, a)
a.workspace = { id = 4 }
move(action, 150)
expect()

action = reset({}, nil)
move(action, 150)
expect()
a.floating = true
action = reset({ a, b }, a)
move(action, 150)
expect()
print("window_focus_swipe: all tests passed")
