-- Fullscreen takeover restores one tiled window and expands another. Animating
-- those intermediate geometries causes flying/flickering windows during swipes.
-- Do not switch layout algorithms: that would discard the dwindle split tree.
local suppressed

local function activeIsFullscreen()
	local active = hl.get_active_window()
	-- Hyprland uses nonzero modes for both maximized and true fullscreen.
	return active ~= nil and (active.fullscreen or 0) ~= 0
end

local function setSuppressed(value)
	if suppressed == value then
		return
	end
	suppressed = value
	hl.animation({
		leaf = "windowsMove",
		enabled = not value,
		-- Match the normal parent `windows` animation from init.lua.
		speed = 5,
		bezier = "windows-in-bezier",
	})
end

-- The vertical fullscreen gesture flags its dispatches via
-- hl.explicit_fullscreen_toggle (true = entering, false = leaving). Consuming
-- it here distinguishes a deliberate toggle from a focus takeover: toggles get
-- to animate both ways, takeovers stay suppressed to avoid flicker.
local function consumeToggle()
	local pending = hl.explicit_fullscreen_toggle
	hl.explicit_fullscreen_toggle = nil
	return pending
end

-- An explicit fullscreen toggle (window.fullscreen) should animate: wait for
-- the expand to finish before disabling windowsMove. Focus takeovers arrive via
-- window.active and still suppress right away, so 3-finger horizontal swipes
-- keep their flicker-free behavior. One reusable timer per delay, since oneshot
-- handles expire after their first firing.
local suppressDelay = 200

local restoreTimer
restoreTimer = hl.timer(function()
	restoreTimer:set_enabled(false)
	setSuppressed(activeIsFullscreen())
end, { timeout = 80, type = "repeat" })
restoreTimer:set_enabled(false)

local suppressTimer
suppressTimer = hl.timer(function()
	suppressTimer:set_enabled(false)
	-- The window may have left fullscreen before the delay elapsed.
	if activeIsFullscreen() then
		setSuppressed(true)
	end
end, { timeout = suppressDelay, type = "repeat" })
suppressTimer:set_enabled(false)

local function update(event)
	if activeIsFullscreen() then
		restoreTimer:set_enabled(false)
		if event == "window.fullscreen" then
			consumeToggle()
			suppressTimer:set_enabled(true)
		else
			-- A focus/workspace change supersedes any pending toggle flag.
			consumeToggle()
			suppressTimer:set_enabled(false)
			setSuppressed(true)
		end
	else
		suppressTimer:set_enabled(false)
		-- A deliberate toggle off must re-enable right away, before Hyprland
		-- configures the shrink animation. Takeover gaps keep the 80ms hold.
		if consumeToggle() == false then
			restoreTimer:set_enabled(false)
			setSuppressed(false)
		elseif suppressed then
			restoreTimer:set_enabled(true)
		end
	end
end

for _, event in ipairs({
	"window.fullscreen",
	"window.active",
	"window.close",
	"workspace.active",
	"workspace.special_active",
	"hyprland.start",
}) do
	hl.on(event, function() update(event) end)
end

-- Also apply on config reload, including when a window is already fullscreen.
setSuppressed(activeIsFullscreen())
