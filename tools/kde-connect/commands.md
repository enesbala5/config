# KDE Connect

## Run Commands Plugin

- Rclone Start

```bash
notify-send "🔃 Starting rclone service" && hyprctl dispatch exec '[float; size 90% 80%; move 5% 10%;]' kitty "zsh -c 'sudo systemctl start rclone.timer rclone.path rclone.service; journalctl -u rclone.service -f; zsh -i'"
```

- Rclone Logs

```bash
hyprctl dispatch exec '[float; size 90% 80%; move 5% 10%;]' kitty "journalctl -u rclone.service -f"
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
