# Excerpts

Short patterns from the canonical posts. Match this rhythm; do not paste these
into a new article.

Source 1 = `nixos-stylix-polarity-toggle.md` (prefer).
Source 2 = `coolify-setup-home-server.md`.

## Situation open

Source 1:

> If you run `NixOS` with Stylix, you already get system-wide theming - GTK apps, terminals, Waybar, and a long list of other modules pick up your `base16` scheme and polarity automatically.
>
> The difficult part is switching between dark and light. A full rebuild just to flip `stylix.polarity` is too slow for something you might want several times a day. Typing a password every time you toggle is also annoying.

Source 2:

> If you use Coolify and also own a home server, you might find yourself in a situation like this - you rent a Remote VPS (eg. Hetzner), which is running a Coolify instance. You may have noticed the `Servers` feature in your Coolify instance, and thought about connecting your existing home server, so that it helps serve requests to your user and speeds up the build process, etc..

## Scope skip + promise

Source 2:

> There are many guides online for setting up `Cloudflare Tunnels` and creating a `Zero Trust Access Application` to expose SSH to a subdomain of your choosing - so I will not explain the steps in this article.

Source 1:

> In this article I'll walk through how I set up an instant dark / light toggle with NixOS, Stylix, and Hyprland. A single keypress flips polarity, swaps the wallpaper, and reloads Hyprland without prompting for a password.
>
> My complete NixOS setup is open source on GitHub - including the files used in this setup.

## Challenge → numbered needs → solution map

Source 1:

> `Stylix` is declarative. Your polarity lives in the Nix config, so changing it normally means editing the file and running `nixos-rebuild switch` (or at least `home-manager switch`). That works, but it is not a "press a key and the desktop flips" workflow.
>
> What we need instead:
>
> 1. Both themes available on the same system generation
> 2. A way to activate one or the other without a rebuild
> 3. No `sudo` password prompt on every toggle
> 4. A keybind (and optionally a shell alias) that runs the switch
>
> NixOS `specialisation`s solve (1) and (2). You declare a light (and optionally dark) specialisation that only overrides `stylix.polarity` / `base16Scheme`. Each generation then ships with switchable variants under `/run/current-system/specialisation/...`.
>
> Passwordless `sudo` for the two `switch-to-configuration` paths solves (3). A short bash script plus a Hyprland bind solves (4).

## Callout as personal trade-off

Source 1:

> [!warning] Does not survive reboot
> `/tmp` is cleared on reboot, so after a restart the script assumes dark (which matches the boot default). That trade-off is fine for me - the system boots dark, and the marker only matters within a session.

## Name what does not just work

Source 1:

> After the switch + `hyprctl reload`:
>
> - Many Stylix-aware apps pick up the new theme immediately (browsers often flip, Obsidian reacts, Kitty usually does too)
> - Some terminals may need a soft reload (e.g. Ghostty: `Ctrl+Shift+,`)
> - Apps like LibreOffice, Firefox, or Thunar often need **all instances closed** before the new polarity sticks

Source 2:

> Note: It's possible to use alternate usernames besides root but that didn't work for me personally and created issues with the `sudoers` file
>
> [!info] You may get the issue "Hostname / Domain already in use"
> I went ahead and ignored it, everything worked fine. If anyone has a better solution, please let me know in the comment section.

## Conclusion as mechanism list

Source 1:

> NixOS specialisations turn a normally rebuild-heavy Stylix polarity change into something you can bind to a single key. The pattern is small:
>
> - Base config stays dark
> - A `light` specialisation overrides polarity + scheme
> - Passwordless sudo only for the two switch binaries
> - A `/tmp` marker + script for toggle state
> - A Hyprland keybind to run it
>
> Wallpaper and `notify-send` are optional polish, but they make the switch feel intentional instead of silent.

## Credit

Source 2:

> I want to thank **Darren** (@frostfelll) - a Community Expert from Coolify's Discord
>
> He was very helpful and proposed the SSH tunnel solution to me. Couldn't have prepared this article without some of his tips.

Source 1:

> This approach is adapted from a Vimjoyer setup that uses NixOS `specialisation`s for light mode, plus a small bash script to switch between them. I ported it to `Hyprland` and added wallpaper + notification polish on top.
