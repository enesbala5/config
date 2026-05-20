I just set it up following this video by Vimjoyer and reading a bit from the docs (under Modules there is specific info for a bunch of apps). Everything works perfectly out of the box

Then i declare a specialization (line 195 of the configuration.nix):

```nix
specialisation.light.configuration = {
  stylix.polarity = lib.mkForce "light";
};
```

So on each generation there is the normal version and the specialization which is in light mode. Then this lets my user change between them without a password (which would be annoying):

```nix
security.sudo.extraRules = [
  {
    users = [ "pau" ];
    commands =[
      { command = "/run/current-system/specialisation/light/bin/switch-to-configuration"; options = [ "NOPASSWD" ]; }
      { command = "/nix/var/nix/profiles/system/bin/switch-to-configuration"; options = [ "NOPASSWD" ]; }
    ];
  }
];
```

Finally, i have this bash script that lets me switch between the light specialization and the normal one (using a dummy file is the best i could think of, but doesnt survive rebooting) and then reloads sway so that waybar changes too. That applies the theme change instantly (reddit changes to light mode, for example) and apps like obsidian react instantly (kitty does that too, but for ghostty i need to do ctrl+shift+,). Apps like libre office, firefox or thunar need to be closed (all instances) for the changes to take effect.

On my Sway config i can switch between themes with the f12 media key (the one with the framework logo): bindsym XF86AudioMedia exec toggle-theme 


---

config/toggle-theme.sh

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

swaymsg reload || true
```