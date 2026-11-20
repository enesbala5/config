-- Run from repository root: lua hypr/hyprland/modules/look_and_feel/tests/fullscreen_animations_test.lua
local active, events, animations, timers
hl = {
	get_active_window = function() return active end,
	on = function(event, callback) events[event] = callback end,
	animation = function(spec) animations[#animations + 1] = spec end,
	timer = function(callback, opts)
		assert(opts.type == "repeat")
		local handle = {
			callback = callback,
			timeout = opts.timeout,
			enabled = false,
			set_enabled = function(self, enabled) self.enabled = enabled end,
		}
		timers[#timers + 1] = handle
		return handle
	end,
}
local function reset(window)
	active, events, animations, timers = window, {}, {}, {}
	hl.explicit_fullscreen_toggle = nil
	dofile("hypr/hyprland/modules/look_and_feel/fullscreen_animations.lua")
end
local function expectEnabled(enabled)
	local spec = animations[#animations]
	assert(spec.leaf == "windowsMove" and spec.enabled == enabled)
	assert(spec.speed == 5 and spec.bezier == "windows-in-bezier")
end
local function timer(timeout)
	for _, handle in ipairs(timers) do
		if handle.timeout == timeout then return handle end
	end
	error("no timer with timeout " .. timeout)
end
local function settle(handle)
	assert(handle.enabled, "timer was not scheduled")
	handle.callback()
	assert(not handle.enabled, "timer should be idle after restoring")
end
local suppressDelay = assert(tonumber(
	io.open("hypr/hyprland/modules/look_and_feel/fullscreen_animations.lua", "r")
		:read("*a"):match("local suppressDelay = (%d+)")))

-- Normal reload restores the original animation, without changing layouts.
reset({ fullscreen = 0 })
expectEnabled(true)
assert(not timer(80).enabled and not timer(suppressDelay).enabled)
local count = #animations
events["window.active"]()
assert(#animations == count and not timer(80).enabled and not timer(suppressDelay).enabled)

-- Fullscreen and maximized immediately disable geometry animation on reload.
for _, mode in ipairs({ 1, 2 }) do
	reset({ fullscreen = mode })
	expectEnabled(false)
	assert(not timer(80).enabled and not timer(suppressDelay).enabled)
	active.fullscreen = 0
	events["window.fullscreen"]()
	expectEnabled(false)
	settle(timer(80))
	expectEnabled(true)
end

-- An explicit toggle animates: suppression waits for the expand, then latches.
reset({ fullscreen = 0 })
active.fullscreen = 2
events["window.fullscreen"]()
expectEnabled(true)
assert(timer(suppressDelay).enabled, "suppression should be pending")
assert(not timer(80).enabled)
settle(timer(suppressDelay))
expectEnabled(false)
assert(not timer(80).enabled)

-- A deliberate toggle off re-enables immediately, before the shrink animation
-- is configured, so leaving fullscreen animates too.
reset({ fullscreen = 2 })
hl.explicit_fullscreen_toggle = false
active.fullscreen = 0
events["window.fullscreen"]()
expectEnabled(true)
assert(not timer(80).enabled and not timer(suppressDelay).enabled)
assert(hl.explicit_fullscreen_toggle == nil, "toggle flag should be consumed")

-- A takeover after a toggle still holds through the intermediate gap: the
-- enter event consumed the flag, so the exit is not mistaken for a toggle off.
reset({ fullscreen = 0 })
hl.explicit_fullscreen_toggle = true
active.fullscreen = 2
events["window.fullscreen"]()
assert(hl.explicit_fullscreen_toggle == nil)
assert(timer(suppressDelay).enabled)
settle(timer(suppressDelay))
expectEnabled(false)
active.fullscreen = 0
events["window.fullscreen"]()
assert(timer(80).enabled, "takeover gap must hold animations")
active = { fullscreen = 2 }
events["window.active"]()
assert(not timer(80).enabled)
expectEnabled(false)

-- A focus change while a toggle flag is pending drops the stale flag.
reset({ fullscreen = 0 })
hl.explicit_fullscreen_toggle = false
active = { fullscreen = 0 }
events["workspace.active"]()
assert(hl.explicit_fullscreen_toggle == nil)

-- Focus takeover (3-finger horizontal swipe) suppresses immediately and
-- cancels a pending toggle suppression.
reset({ fullscreen = 0 })
active.fullscreen = 2
events["window.fullscreen"]()
assert(timer(suppressDelay).enabled)
events["window.active"]()
assert(not timer(suppressDelay).enabled)
expectEnabled(false)

-- Toggling back out before the delay fires leaves animations enabled. A stale
-- callback from that cancelled timer must not suppress either.
reset({ fullscreen = 0 })
active.fullscreen = 2
events["window.fullscreen"]()
assert(timer(suppressDelay).enabled)
active.fullscreen = 0
events["window.fullscreen"]()
assert(not timer(suppressDelay).enabled)
timer(suppressDelay).callback()
expectEnabled(true)
assert(#animations == 1)

-- No transient re-enable between the old and new fullscreen windows.
reset({ fullscreen = 2 })
active.fullscreen = 0
events["window.fullscreen"]()
assert(timer(80).enabled)
active = { fullscreen = 2 }
events["window.active"]()
assert(not timer(80).enabled)
expectEnabled(false)
assert(#animations == 1, "takeover must not toggle the animation")

-- Moving to a normal workspace restores animations; returning disables again.
active = { fullscreen = 0 }
events["workspace.active"]()
settle(timer(80))
expectEnabled(true)
active = { fullscreen = 2 }
events["workspace.active"]()
expectEnabled(false)

-- Floating/normal special-workspace focus uses normal move animations.
active = { fullscreen = 0, floating = true }
events["workspace.special_active"]()
settle(timer(80))
expectEnabled(true)

-- Closing the last focused window restores animations after events settle.
reset({ fullscreen = 2 })
active = nil
events["window.close"]()
settle(timer(80))
expectEnabled(true)

-- Recheck state when the timer fires, even if a focus event was missed.
reset({ fullscreen = 2 })
active.fullscreen = 0
events["window.fullscreen"]()
active.fullscreen = 2
settle(timer(80))
expectEnabled(false)
assert(#animations == 1)

-- A takeover arriving while a delayed suppression is pending suppresses now.
reset({ fullscreen = 0 })
active.fullscreen = 2
events["window.fullscreen"]()
assert(timer(suppressDelay).enabled)
active = { fullscreen = 2 }
events["workspace.active"]()
assert(not timer(suppressDelay).enabled)
expectEnabled(false)

-- Startup with no focused window remains animated.
reset(nil)
events["hyprland.start"]()
expectEnabled(true)
print("fullscreen_animations: all tests passed")
