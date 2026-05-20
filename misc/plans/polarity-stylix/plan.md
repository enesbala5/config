# Plan: Polarity Toggle (Stylix Dark/Light)

## Overview

Adapt the guide's approach to this setup: NixOS + Hyprland, using `data.username` and `data.configDirectory` conventions.

---

## Steps

### 1. Add `sudo.extraRules` to `base-configuration.nix`

Inside the existing `security` block, extend `sudo` with `extraRules`:

```nix
security = {
  sudo = {
    enable = true;
    extraRules = [
      {
        users = [ data.username ];
        commands = [
          { command = "/run/current-system/specialisation/light/bin/switch-to-configuration"; options = [ "NOPASSWD" ]; }
          { command = "/nix/var/nix/profiles/system/bin/switch-to-configuration"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
  # ... rest unchanged
};
```

### 2. Create `scripts/utilities/toggle-polarity.sh`

Adapted from the guide — replace `swaymsg reload` with `hyprctl reload`:

```bash
#!/usr/bin/env bash
DUMMY_FILE="/tmp/light_mode_active"
if [ -f "$DUMMY_FILE" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration test
  rm -f "$DUMMY_FILE"
else
  sudo /run/current-system/specialisation/light/bin/switch-to-configuration test
  touch "$DUMMY_FILE"
fi

hyprctl reload || true
```

Mark it executable (`chmod +x` or via Nix `home.file` with `executable = true`).

### 3. Add F12 keybinding in `hypr/hyprland/configuration.conf`

Next to the existing media key bindings (around line 279–281):

```
bind =, XF86AudioMedia, exec, ~/config/scripts/utilities/toggle-polarity.sh
```

`XF86AudioMedia` is the keysym for the Framework logo / F12 media key, matching the guide's `bindsym XF86AudioMedia`.

### 4. Add shell alias in `misc/nix/nixos/modules/home/programs/zsh.nix`

In the `shellAliases` block, mirroring `reload-hyprlock`:

```nix
toggle-polarity = "${data.configDirectory}/scripts/utilities/toggle-polarity.sh";
```

---

## Files changed

| File | Change |
|---|---|
| `misc/nix/nixos/modules/base-configuration.nix` | Add `sudo.extraRules` for the two switch-to-configuration paths |
| `scripts/utilities/toggle-polarity.sh` | New script (executable) |
| `hypr/hyprland/configuration.conf` | Add `XF86AudioMedia` bind |
| `misc/nix/nixos/modules/home/programs/zsh.nix` | Add `toggle-polarity` alias |

---

## Notes

- The dummy file `/tmp/light_mode_active` does not survive reboots (same trade-off as the guide — acceptable).
- `switch-to-configuration test` applies the config without making it the boot default, which is the intended behavior.
- No changes needed to the `stylix` or `specialisation` blocks — those are already declared correctly in the existing config.
