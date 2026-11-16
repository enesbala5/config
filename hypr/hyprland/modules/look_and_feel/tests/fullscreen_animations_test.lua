-- Run from repository root: lua hypr/hyprland/modules/look_and_feel/tests/fullscreen_animations_test.lua
local active, events, animations, timer
hl = {
	get_active_window = function() return active end,
	on = function(event, callback) events[event] = callback end,
	animation = function(spec) animations[#animations + 1] = spec end,
	timer = function(callback, opts)
		assert(opts.type == "repeat" and opts.timeout == 80)
		timer = {
			callback = callback,
			enabled = true,
			set_enabled = function(self, enabled) self.enabled = enabled end,
		}
		return timer
	end,
}
local function reset(window)
	active, events, animations = window, {}, {}
	dofile("hypr/hyprland/modules/look_and_feel/fullscreen_animations.lua")
end
local function expectEnabled(enabled)
	local spec = animations[#animations]
	assert(spec.leaf == "windowsMove" and spec.enabled == enabled)
	assert(spec.speed == 5 and spec.bezier == "windows-in-bezier")
end
local function settle()
	assert(timer.enabled, "restore was not scheduled")
	timer.callback()
	assert(not timer.enabled, "timer should be idle after restoring")
end

-- Normal reload restores the original animation, without changing layouts.
reset({ fullscreen = 0 })
expectEnabled(true)
assert(not timer.enabled)
local count = #animations
events["window.active"]()
assert(#animations == count and not timer.enabled)

-- Fullscreen and maximized immediately disable geometry animation.
for _, mode in ipairs({ 1, 2 }) do
	reset({ fullscreen = mode })
	expectEnabled(false)
	assert(not timer.enabled)
	active.fullscreen = 0
	events["window.fullscreen"]()
	expectEnabled(false)
	settle()
	expectEnabled(true)
end

-- No transient re-enable between the old and new fullscreen windows.
reset({ fullscreen = 2 })
active.fullscreen = 0
events["window.fullscreen"]()
assert(timer.enabled)
active = { fullscreen = 2 }
events["window.active"]()
assert(not timer.enabled)
expectEnabled(false)
assert(#animations == 1, "takeover must not toggle the animation")

-- Moving to a normal workspace restores animations; returning disables again.
active = { fullscreen = 0 }
events["workspace.active"]()
settle()
expectEnabled(true)
active = { fullscreen = 2 }
events["workspace.active"]()
expectEnabled(false)

-- Floating/normal special-workspace focus uses normal move animations.
active = { fullscreen = 0, floating = true }
events["workspace.special_active"]()
settle()
expectEnabled(true)

-- Closing the last focused window restores animations after events settle.
reset({ fullscreen = 2 })
active = nil
events["window.close"]()
settle()
expectEnabled(true)

-- Recheck state when the timer fires, even if a focus event was missed.
reset({ fullscreen = 2 })
active.fullscreen = 0
events["window.fullscreen"]()
active.fullscreen = 2
settle()
expectEnabled(false)
assert(#animations == 1)

-- Startup with no focused window remains animated.
reset(nil)
events["hyprland.start"]()
expectEnabled(true)
print("fullscreen_animations: all tests passed")
