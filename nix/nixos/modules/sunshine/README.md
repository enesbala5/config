# Sunshine + Moonlight (on-demand)

Shared NixOS module (`modules.sunshine`) for streaming a host's **existing**
Hyprland desktop, including audio and remote input. Enabled on `framework-13`
and `home-server`; Hypruse remains available independently. Moonlight clients
exist for Windows, macOS, Linux, Android, and iOS/iPadOS:
<https://moonlight-stream.org/>.

## Security and lifecycle

- Streaming ingress is allowed only on `tailscale0` (IPv4). No router forwarding
  is needed; UPnP is disabled. Tailnet ACLs/grants still decide which peers may
  connect. Pair only trusted clients: they can control the real desktop.
- The admin UI accepts localhost connections only. Port 47990 is never opened
  on Tailscale or LAN. Use the local browser or an SSH tunnel for administration.
- Sunshine is **off by default on every host**: `autoStart = false` and neither
  user service has a `wantedBy`, so nothing starts at boot or login. Run
  `manage-sunshine on` inside the host's Hyprland session when needed, and
  `manage-sunshine off` when finished. Disconnecting Moonlight does **not** stop
  Sunshine. Keeping it off avoids background resource use.
- These hosts start Hyprland directly via GDM autologin (their
  `graphical-session.target` is inactive). `manage-sunshine` imports the session
  environment and starts `sunshine-session.service`, which watches Hyprland's
  event socket. Sunshine binds to that watcher, stopping when the compositor
  exits. The upstream NixOS module configures uinput/udev and supplies a
  `CAP_SYS_ADMIN` wrapper for KMS capture. That capability is powerful; it is
  required for this capture method, not a reason to run the whole service as
  root. AMD encoding uses VA-API.
- Sunshine configuration and the Desktop application are declarative. Change
  `default.nix` rather than expecting web UI edits to persist. Credentials,
  pairing keys, and certificates stay in Sunshine's writable user state
  (normally `~/.config/sunshine`), never in Nix or Git.
- Lid-close, idle suspend, screen locking, and display settings are unchanged.
  The host must be awake with a logged-in graphical session and an active
  output. This does not provide disk unlock, a login screen, or wake-on-demand.

## On-demand CLI

`manage-sunshine` calls `scripts/utilities/manage-sunshine.sh`:

```sh
manage-sunshine on       # Start from a terminal inside the host's Hyprland session
manage-sunshine off      # Stop Sunshine and its watcher; also disconnects clients
manage-sunshine status   # Show both units (nonzero exit status when inactive)
manage-sunshine restart  # Restart with the current Hyprland environment
manage-sunshine logs     # Follow both journals; Ctrl-C exits without stopping Sunshine
manage-sunshine help
```

No sudo is needed for these user-service commands. `on` is idempotent. `on`,
`restart`, and `off` print progress and confirm the state of **both** services.
Startup checks service activity for up to five seconds; this confirms systemd
state, not successful capture/encoding or Moonlight connectivity. Failures
return a nonzero exit code and show service status plus the last 30 journal
entries. The script sets `XDG_SESSION_TYPE=wayland` for the validated Hyprland
environment and skips unset optional variables, avoiding misleading import
warnings. Stopping Sunshine does not remove credentials or paired clients.
Logging back in does not restart it; turn it on again when needed.

## First connection

1. Apply the config on the host you want to stream from:

   ```sh
   # Laptop
   sudo nixos-rebuild switch --flake ~/config/nix/nixos#framework-13
   # Server
   sudo nixos-rebuild switch --flake ~/config/nix/nixos#home-server
   ```

   Log out and back in to refresh group membership. Open a new zsh terminal,
   start Sunshine on demand, and check the service:

   ```sh
   manage-sunshine on
   manage-sunshine status
   journalctl --user -u sunshine -b --no-pager -n 100
   ```

2. On that host open <https://localhost:47990>, accept the self-signed
   certificate warning, and create a unique admin username/password. For remote
   administration from a computer with SSH access:

   ```sh
   ssh -N -L 47990:127.0.0.1:47990 e@<host-tailscale-ip>
   ```

   Open <https://localhost:47990> on that computer and keep the tunnel running
   while pairing. For phones/tablets, approve their PIN in the host's local
   browser or in the tunneled browser on another computer.

3. Install Tailscale and Moonlight on the client and join the same tailnet.
   Run `tailscale ip -4` on the host, add that IPv4 address manually in
   Moonlight (discovery across Tailscale is not expected), then enter the
   PIN shown in Sunshine's **PIN** page. Repeat for each device.

4. Select **Desktop** in Moonlight. Start with 1080p, 60 FPS, H.264, and
   10–20 Mbps. Streaming resolution does not resize the physical desktop.
   Adjust quality once video, audio, mouse, and keyboard work.

## Manual acceptance checklist

Run on the actual host after rebuilding; evaluation alone cannot prove capture,
encoding, firewall enforcement, or client behavior.

- Connect from Windows, macOS, Linux, Android, and iOS/iPadOS. Verify desktop
  video, audio, clicks, scrolling, typing, and disconnect/reconnect. Verify
  hardware VA-API encoding in Sunshine's log, not just successful streaming.
- From a tailnet peer, `tailscale ping <host-tailscale-ip>`; a direct path is
  preferable to DERP relay for video. `curl -k --connect-timeout 3
  https://<host-tailscale-ip>:47990` should fail, while the localhost/SSH-tunnel
  UI works.
- From another machine on the physical LAN, without routing through Tailscale,
  `nc -vz -w 3 <host-lan-ip> 47984 47989 47990 48010` should fail. Inspect
  active firewall rules for the UDP/interface restrictions too.
- Both units must remain inactive after login/reboot until `manage-sunshine on`.
  Verify `on`, `status`, `restart`, and `off`. While running, log out: Sunshine
  and its watcher should stop. Log back in: both should stay stopped.
  Disconnecting Moonlight alone should leave Sunshine running; use `off`.
- Normal sleep policy and Hypruse should still work as before.

## Troubleshooting

- **Service inactive after login:** intentional. Run `manage-sunshine on` in a
  Hyprland terminal. If startup fails, inspect `manage-sunshine status`,
  `manage-sunshine logs`, and `systemctl --user show-environment`. Before the
  command is on PATH, use `bash ~/config/scripts/utilities/manage-sunshine.sh on`
  so environment setup and service checks are included.
- **Black screen / encoder failure:** check the journal, `/dev/dri` permissions,
  `id` (video/render membership), and `getcap /run/wrappers/bin/sunshine`.
  `hyprctl monitors` should show an enabled output. KMS capture is deliberate
  instead of relying on wlroots screencopy support.
- **No input:** inspect `/dev/uinput` permissions and Sunshine's input errors;
  the upstream module installs the required udev rules. Re-login/reboot if
  permissions have not refreshed; do not make input devices world-writable.
- **Poor performance / no connection:** check tailnet policy and direct vs
  relayed connectivity, lower bitrate/resolution, and inspect the service log.
  Do not fix this by globally opening Sunshine ports or enabling UPnP.

Clipboard/file transfer is not configured. Use a separate tool for those.
