# Framework 13: Sunshine + Moonlight

Streams the **existing** Hyprland desktop, including its audio and remote input.
Hypruse remains available independently. Moonlight clients are available for
Windows, macOS, Linux, Android, and iOS/iPadOS: <https://moonlight-stream.org/>.

## Security and lifecycle

- Streaming ingress is allowed only on `tailscale0` (IPv4). No router forwarding
  is needed; UPnP is disabled. Tailnet ACLs/grants still determine which peers
  may connect. Pair only trusted clients: they can control the real desktop.
- The admin UI accepts localhost connections only, and port 47990 is not opened
  on Tailscale or LAN. Use the local browser or an SSH tunnel for administration.
- Sunshine is **manual-only**: it does not start at login or boot. Run
  `manage-sunshine on` inside the laptop's Hyprland session when needed, and
  `manage-sunshine off` when finished. Disconnecting Moonlight does **not** stop
  Sunshine. Keeping it off avoids its background resource use on battery.
- This host starts Hyprland directly (its `graphical-session.target` is inactive).
  `manage-sunshine` imports the session environment and starts
  `sunshine-session.service`, which watches Hyprland's event socket. Sunshine
  binds to that watcher, stopping when the compositor exits. The upstream NixOS
  module configures uinput/udev and supplies a `CAP_SYS_ADMIN` wrapper for KMS capture.
  This capability is powerful; it is required for this capture method, not a
  reason to run the entire service as root. AMD encoding uses VA-API.
- Sunshine configuration and the Desktop application are declarative. Change
  `default.nix` rather than expecting web UI configuration edits to persist.
  Credentials, pairing keys, and certificates stay in Sunshine's writable user
  state (normally `~/.config/sunshine`), never in Nix or Git.
- Lid-close, idle suspend, screen locking, and display settings are unchanged.
  The host must be awake with a logged-in graphical session and an active output.
  This does not provide disk unlock, a login screen, or wake-on-demand.

## On-demand CLI

The zsh alias calls `scripts/utilities/manage-sunshine.sh`:

```sh
manage-sunshine on       # Start from a terminal inside the laptop Hyprland session
manage-sunshine off      # Stop Sunshine and its watcher; also disconnects clients
manage-sunshine status   # Show both units (nonzero exit status when inactive)
manage-sunshine restart  # Restart with the current Hyprland environment
manage-sunshine logs     # Follow both journals; Ctrl-C exits without stopping Sunshine
manage-sunshine help
```

After rebuilding, open a new zsh terminal to load the alias. Before rebuilding,
use `bash ~/config/scripts/utilities/manage-sunshine.sh on` (or `off`, etc.), or
load the alias into the current zsh session:

```sh
alias manage-sunshine='bash ~/config/scripts/utilities/manage-sunshine.sh'
```

No sudo is needed for these user-service commands. `on` is idempotent. Stopping
Sunshine does not remove credentials or paired clients. Logging back in does
not restart it; explicitly turn it on again when needed.

## First connection

1. After merging/checking out this change in `~/config`, apply it on the laptop:

   ```sh
   sudo nixos-rebuild switch --flake ~/config/nix/nixos#framework-13
   ```

   Log out and back in to refresh group membership and the graphical session.
   Open a new zsh terminal, start Sunshine on demand, and check the service:

   ```sh
   manage-sunshine on
   manage-sunshine status
   journalctl --user -u sunshine -b --no-pager -n 100
   ```

2. On the laptop open <https://localhost:47990>, accept the expected self-signed
   certificate warning, and create a unique admin username/password. For remote
   administration from a computer with SSH access, use:

   ```sh
   ssh -N -L 47990:127.0.0.1:47990 e@<fw13-tailscale-ip>
   ```

   Open <https://localhost:47990> on that computer. Keep the tunnel running while
   pairing. For phones/tablets, approve their PIN in the laptop's local browser
   or in this tunneled browser on another computer.

3. Install Tailscale and Moonlight on the client and join the same tailnet.
   Run `tailscale ip -4` on the laptop, then manually add that IPv4 address in
   Moonlight. Discovery across Tailscale is not expected. Start pairing and enter
   Moonlight's PIN in Sunshine's **PIN** page. Repeat for each device.

4. Select **Desktop** in Moonlight. Start with 1080p, 60 FPS, H.264, and
   10–20 Mbps. Streaming resolution does not automatically resize the physical
   desktop. Adjust quality once video, audio, mouse, and keyboard work.

## Manual acceptance checklist

Run on the actual laptop after rebuilding; evaluation alone cannot prove capture,
encoding, firewall enforcement, or client behavior.

- Connect from Windows, macOS, Linux, Android, and iOS/iPadOS. Verify desktop
  video, audio, clicks, scrolling, typing, and disconnect/reconnect. Verify
  hardware VA-API encoding in Sunshine's log, not just successful streaming.
- From a tailnet peer, check `tailscale ping <fw13-tailscale-ip>`; a direct path
  is preferable to DERP relay for video. Confirm successful pairing/streaming.
  Try `curl -k --connect-timeout 3 https://<fw13-tailscale-ip>:47990`:
  it should fail, while the localhost/SSH-tunnel UI works.
- From another machine on the physical LAN, without routing through Tailscale,
  check that `nc -vz -w 3 <fw13-lan-ip> 47984 47989 47990 48010` fails.
  Inspect active firewall rules as well for the UDP/interface restrictions.
- Lock with Hyprlock during a stream and test reconnect/unlock. Test display-off
  and closed-lid behavior separately with physical access available. Do not
  disable locking to fix streaming. Suspend should make the host unavailable;
  after local wake, verify reconnect. No headless/closed-lid guarantee is made.
- After login/reboot, both units should remain inactive until `manage-sunshine on`.
  Verify `on`, `status`, `restart`, and `off`. While running, log out: Sunshine
  and its session watcher should stop. Log back in: both should remain stopped.
  Disconnecting Moonlight alone should leave Sunshine running; use `off` after
  streaming. Normal sleep policy and Hypruse should still work as before.

## Troubleshooting

- **Service inactive after login:** this is intentional. Run `manage-sunshine on`
  in a laptop Hyprland terminal. If startup fails, inspect `manage-sunshine status`,
  `manage-sunshine logs`, and `systemctl --user show-environment`.
  The equivalent commands, useful before the alias is available, are:

  ```sh
  systemctl --user import-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
  systemctl --user start sunshine-session.service
  ```

  Inspect both units' journals. `graphical-session.target` need not be active.
- **Black screen / encoder failure:** check the journal, `/dev/dri` permissions,
  `id` (video/render membership), and `getcap /run/wrappers/bin/sunshine`.
  `hyprctl monitors` should show an enabled output. KMS capture is deliberately
  used instead of relying on Hyprland supporting wlroots screencopy.
- **No input:** inspect `/dev/uinput` permissions and Sunshine's input errors;
  the upstream module installs the required udev rules. Re-login/reboot if
  permissions have not refreshed; do not make input devices world-writable.
- **Poor performance / no connection:** check tailnet policy and direct versus
  relayed connectivity, lower bitrate/resolution, and inspect the service log.
  Do not fix this by globally opening Sunshine ports or enabling UPnP.

Clipboard/file transfer is not configured. Use a separate tool for those.
