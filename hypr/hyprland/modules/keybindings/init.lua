-- Keybindings. Required from hyprland.lua as `require("modules.keybindings")`.

local terminal = "kitty"
local helium = "helium --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1 --remote-allow-origins=*"
local textEditor = "obsidian"
local fileManager = "dolphin"
local fileManagerSecondary = "thunar"
local clipboardManager = "vicinae vicinae://launch/clipboard/history"
local clipboardManagerBackup = "cliphist list | vicinae dmenu --placeholder \"Select option\" | cliphist decode | wl-copy"
local codeEditor = "zeditor"
local menu = "vicinae toggle"
local emojiPicker = "vicinae vicinae://launch/core/search-emojis"
local super = "SUPER"

hl.bind(super .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(super .. " + Z", hl.dsp.exec_cmd(codeEditor))
hl.bind(super .. " + H", hl.dsp.exec_cmd(helium))

hl.bind(super .. " + Q", hl.dsp.window.close())
hl.bind(super .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(super .. " + CTRL + SHIFT + B", hl.dsp.exec_cmd("hyprdynamicmonitors run"))
hl.bind(super .. " + CTRL + SHIFT + L", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(
	super .. " + CTRL + SHIFT + M",
	hl.dsp.exec_cmd("kitty zsh -c '~/config/scripts/utilities/clear-monitor-lua.sh; zsh -i'", {
		float = true,
		size = { "monitor_w * 0.9", "monitor_h * 0.8" },
		move = { "monitor_w * 0.05", "monitor_h * 0.1" },
	})
)
hl.bind(
	super .. " + CTRL + ESCAPE",
	hl.dsp.exec_cmd("kitty btop", {
		float = true,
		size = { "monitor_w * 0.9", "monitor_h * 0.8" },
		move = { "monitor_w * 0.05", "monitor_h * 0.1" },
	})
)
hl.bind(super .. " + ESCAPE", hl.dsp.exec_cmd("dunstctl close"))

hl.bind(super .. " + X", hl.dsp.exec_cmd("~/config/scripts/audio/handy-bt-toggle.sh"))
hl.bind(super .. " + SHIFT + M", hl.dsp.exec_cmd("~/config/scripts/audio/toggle_sink.sh"))
hl.bind(super .. " + C", hl.dsp.exec_cmd("~/config/scripts/utilities/cancel.sh"))
hl.bind(super .. " + S", hl.dsp.exec_cmd("~/config/scripts/audio/hypr-piper-speak.sh -l en"))
hl.bind(super .. " + ALT + S", hl.dsp.exec_cmd("~/config/scripts/audio/hypr-piper-speak.sh"))

hl.bind(super .. " + CTRL + L", hl.dsp.exec_cmd("pidof hyprlock --no-fade-in || hyprlock"))
hl.bind(super .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(super .. " + SHIFT + E", hl.dsp.exec_cmd(fileManagerSecondary))
hl.bind(super .. " + N", hl.dsp.exec_cmd(textEditor))
hl.bind(super .. " + M", hl.dsp.exec_cmd("vicinae vicinae://launch/@dagimg-dot/store.vicinae.player-pilot/player-pilot"))
hl.bind(super .. " + P", hl.dsp.exec_cmd("~/config/scripts/music/play-pause.sh"))

hl.bind(super .. " + SHIFT + S", hl.dsp.exec_cmd("~/config/scripts/utilities/screenshot.sh"))
hl.bind(super .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("~/config/scripts/utilities/screen-record.sh"))
hl.bind(super .. " + CTRL + SHIFT + D", hl.dsp.exec_cmd("~/config/scripts/utilities/dnd-toggle.sh"))
hl.bind(super .. " + CTRL + SHIFT + I", hl.dsp.exec_cmd("hyprpicker -a"))

hl.bind(super .. " + F", hl.dsp.window.float())
hl.bind(super .. " + CTRL + F", hl.dsp.window.fullscreen())
hl.bind(super .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(super .. " + SHIFT + P", hl.dsp.window.pin())
hl.bind(super .. " + R", hl.dsp.exec_cmd("vicinae vicinae://launch/system/run"))
hl.bind(super .. " + SHIFT + R", hl.dsp.exec_cmd("wofi -show run"))
hl.bind(super .. " + D", hl.dsp.window.pseudo())
hl.bind(super .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(super .. " + CTRL + ALT + SHIFT + left", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(super .. " + CTRL + ALT + SHIFT + right", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(super .. " + CTRL + ALT + SHIFT + up", hl.dsp.workspace.move({ monitor = "u" }))
hl.bind(super .. " + CTRL + ALT + SHIFT + down", hl.dsp.workspace.move({ monitor = "d" }))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brillo -U 5 -e -u 150000"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brillo -A 5 -e -u 150000"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/config/scripts/audio/volume.sh up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/config/scripts/audio/volume.sh down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("~/config/scripts/audio/volume.sh mute"))
hl.bind("XF86AudioMedia", hl.dsp.exec_cmd("~/config/scripts/utilities/toggle-polarity.sh"))

hl.bind(super .. " + V", hl.dsp.exec_cmd(clipboardManager))
hl.bind(super .. " + SHIFT + V", hl.dsp.exec_cmd(clipboardManagerBackup))
hl.bind(super .. " + Period", hl.dsp.exec_cmd(emojiPicker))

hl.bind("ALT + TAB", hl.dsp.window.cycle_next({ tiled = true }))
hl.bind("ALT + TAB", hl.dsp.window.bring_to_top())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false, tiled = true }))
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.bring_to_top())

hl.bind(super .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(super .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(super .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(super .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(super .. " + CTRL + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(super .. " + CTRL + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(super .. " + CTRL + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(super .. " + CTRL + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

hl.bind(super .. " + SHIFT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(super .. " + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(super .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(super .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

hl.bind(super .. " + CTRL + left", hl.dsp.focus({ workspace = "-1" }))
hl.bind(super .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))

hl.bind(super .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(super .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(super .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(super .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(super .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(super .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(super .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(super .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(super .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(super .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(super .. " + CTRL + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(super .. " + CTRL + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(super .. " + CTRL + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(super .. " + CTRL + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(super .. " + CTRL + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(super .. " + CTRL + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(super .. " + CTRL + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(super .. " + CTRL + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(super .. " + CTRL + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(super .. " + CTRL + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind(super .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind("CTRL + SHIFT + F6", hl.dsp.workspace.toggle_special("magic"))

hl.bind(super .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(super .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(super .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(super .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
