---
name: Framework power-saver
overview: Tighten power-saver on the Framework 13 by moving the iGPU, killing borderangle, stopping leftover daemons, slowing the Hyprland ActivityWatch watcher, and removing TeamViewer — without touching VirtualBox, pro-audio behavior, brightness, or PSR.
todos:
  - id: handler-hypr-gpu
    content: Add borderangle-off + iGPU DPM battery/low (restore auto on balanced/performance) in power-profile-handler.sh
    status: pending
  - id: handler-services-aw
    content: Stop libvirtd socket/service in power-saver; drop user teamviewer; set Hyprland AW watcher poll 15s vs 5s and restart that unit
    status: pending
  - id: nix-tv-aw
    content: Remove TeamViewer on fw13; set aw-watcher-window-hyprland --poll-time 5; drop duplicate Hyprland exec-once
    status: pending
  - id: nix-audio-move
    content: Move 51-ryzen-audio-profile from base-configuration.nix to framework-13 host pipewire config unchanged
    status: pending
isProject: false
---

# Framework 13 power-saver tightening

Scope is only what you confirmed. No brightness cap, no PSR change, no hypridle/AC auto-switch, no EasyEffects/KDE Connect toggles, no VirtualBox changes, no pro-audio behavior changes. Same `hyprctl keyword` method.

## Skip

- **KDE Connect:** leave running (idle cost is tiny).
- **EasyEffects:** leave running.
- **PSR:** keep `amdgpu.dcdebugmask=0x10` from nixos-hardware.
- **Docker:** leave running.
- **VirtualBox:** leave `virtualisation.virtualbox.host` and the package as-is.
- **pro-audio / amd-audio-reinit / Ryzen mic rule:** do not change. Only relocate the WirePlumber snippet so it is fw13-specific.

## Handler ([power-profile-handler.sh](scripts/hosts/framework-13/power-profiles/power-profile-handler.sh))

Keep existing VFR/blur/shadow keywords. Add:

**Hyprland (power-saver only)** — still `hyprctl keyword`; balanced/performance already `hyprctl reload` so default `borderangle` comes back:

```bash
run_hyprctl keyword animation "borderangle, 0"
```

**iGPU** — live sysfs is `power_dpm_state=performance` and `force_performance_level=auto` even in power-saver. Loop `/sys/class/drm/card*/device/` and skip missing files (simpledrm has none):

- power-saver: `power_dpm_state=battery`, `power_dpm_force_performance_level=low`
- balanced: `balanced` + `auto`
- performance: `performance` + `auto`

**Services**

- Stop **system** `libvirtd.service` + `libvirtd.socket` in power-saver (start them again on balanced/performance). This is the QEMU/KVM daemon behind virt-manager; virt-manager stays installed. `libvirtd.enable` stays in [base-configuration.nix](nix/nixos/modules/base-configuration.nix) because the home-server shares that module.
- Drop the broken **user** `teamviewer.service` line (it already logs `failed or not present`). TeamViewer is removed in Nix instead.
- Leave docker, cups, ratbagd, rclone as they are.

**ActivityWatch — Hyprland watcher only**

`aw-watcher-window-hyprland` is the hot path: it defaults to `--poll-time 1` and runs `hyprctl` every second for **both** window and workspace. It is also started **twice** today:

- systemd user unit from [activitywatch.nix](nix/nixos/hosts/framework-13/home/programs/activitywatch.nix)
- `exec-once = aw-watcher-window-hyprland` in [hypr/hyprland/configuration.conf](hypr/hyprland/configuration.conf)

Leave `aw-watcher-afk` / `aw-watcher-window` `poll_time = 1000` as-is (already slow; units are seconds).

- Nix: `extraOptions = [ "--poll-time" "5" ];` on the Hyprland watcher (5s in general).
- Remove the Hyprland `exec-once` so only the systemd unit runs (otherwise extraOptions never apply to the duplicate).
- Handler: power-saver restarts that user unit with `--poll-time 15`; balanced/performance put it back on 5s (stop/start the HM unit, or a tiny wrapper that reads a poll file then `systemctl --user restart`). Do not rewrite afk/window toml.

## NixOS host ([framework-13/default.nix](nix/nixos/hosts/framework-13/default.nix))

- **TeamViewer:** remove entirely on fw13 — `services.teamviewer.enable = false` (or drop the option) and drop `teamviewer` from `systemPackages`.
- **Audio:** copy `51-ryzen-audio-profile` into this host’s existing `pipewire.wireplumber.extraConfig` **verbatim** (same `alsa_card.pci-0000_c1_00.6` → `pro-audio` match). Do not change `amd-audio-reinit` or `52-disable-ryzen-mic`.

## NixOS shared ([base-configuration.nix](nix/nixos/modules/base-configuration.nix))

- Delete `51-ryzen-audio-profile` from here after it lives on fw13. Home-server never had that PCI device; this is a move, not a behavior change.

Needs a `nixos-rebuild switch` for TeamViewer, the WirePlumber move, and the Hyprland watcher `--poll-time 5`. Handler GPU/Hyprland/libvirt/AW-15s apply on the next profile change (or restart `power-profile-handler`).
