# KDE Connect

## Run Commands Plugin

- Rclone Start

```bash
notify-send "🔃 Starting rclone service" && hyprctl dispatch 'hl.dsp.exec_cmd("kitty zsh -c \"sudo systemctl start rclone.timer rclone.path rclone.service; journalctl -u rclone.service -f; zsh -i\"", { float = true, size = { "monitor_w * 0.9", "monitor_h * 0.8" }, move = { "monitor_w * 0.05", "monitor_h * 0.1" } })'
```

- Rclone Logs

```bash
hyprctl dispatch 'hl.dsp.exec_cmd("kitty journalctl -u rclone.service -f", { float = true, size = { "monitor_w * 0.9", "monitor_h * 0.8" }, move = { "monitor_w * 0.05", "monitor_h * 0.1" } })'
```

- Suspend

```bash
systemctl suspend
```

- Sleep

```bash
systemctl sleep
```

- Lock Screen

```bash
loginctl lock-session
```

- Toggle Polarity

```bash
~/config/scripts/utilities/toggle-polarity.sh
```

- Reload Hyprlock

```bash
~/config/scripts/utilities/reload-hyprlock.sh
```

- Clear Monitor Config

```bash
sh -c '> ~/.config/hypr/monitors.lua' && pkill -9 -f hyprdynamicmonitors
```

- Run Hyprdynamicmonitors

```bash
hyprdynamicmonitors run
```
