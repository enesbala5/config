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

-- Fullscreen takeover emits an intermediate "not fullscreen" event before the
-- next window takes over. Keep geometry animations disabled through that gap.
-- Use one reusable timer; oneshot timer handles expire after their first firing.
local restoreTimer
restoreTimer = hl.timer(function()
	restoreTimer:set_enabled(false)
	setSuppressed(activeIsFullscreen())
end, { timeout = 80, type = "repeat" })
restoreTimer:set_enabled(false)

local function update()
	if activeIsFullscreen() then
		restoreTimer:set_enabled(false)
		setSuppressed(true)
	elseif suppressed then
		restoreTimer:set_enabled(true)
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
	hl.on(event, update)
end

-- Also apply on config reload, including when a window is already fullscreen.
setSuppressed(activeIsFullscreen())
