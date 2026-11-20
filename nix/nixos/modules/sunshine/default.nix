# On-demand remote desktop streaming for hosts with a Hyprland session.
#
# The module is opt-in per host via `modules.sunshine.enable`. Even when enabled,
# Sunshine is installed but NOT running: both user services have no wantedBy and
# `autoStart` is false. Start it explicitly with `manage-sunshine on` from inside
# the graphical session, and stop it with `manage-sunshine off` afterwards.
{
  config,
  lib,
  pkgs,
  data,
  hostname,
  ...
}:
let
  cfg = config.modules.sunshine;
in
{
  options.modules.sunshine = {
    enable = lib.mkEnableOption "Sunshine remote desktop streaming";

    name = lib.mkOption {
      type = lib.types.str;
      default = if hostname == "framework-13" then "Framework 13" else "Home Server";
      description = "Name Sunshine advertises to Moonlight clients.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      # Off by default: never pull in a graphical session or start at boot/login.
      autoStart = false;
      openFirewall = false;

      # KMS works without the wlroots screencopy protocol. The upstream module
      # wraps Sunshine with CAP_SYS_ADMIN; it still runs as the graphical user.
      capSysAdmin = true;
      settings = {
        sunshine_name = cfg.name;
        capture = "kms";
        encoder = "vaapi";
        address_family = "ipv4";
        upnp = "disabled";
        # Pair locally or through an SSH tunnel; never expose the admin UI.
        origin_web_ui_allowed = "pc";
      };
      applications.apps = [ { name = "Desktop"; } ];
    };

    # GDM autologin starts Hyprland directly on these hosts, without UWSM or an
    # active graphical-session.target. Track the compositor's event socket
    # instead. manage-sunshine imports the session environment and starts this
    # watcher on demand. No wantedBy: neither unit should start automatically.
    systemd.user.services.sunshine-session = {
      description = "Track Sunshine's Hyprland session";
      wants = [ "sunshine.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat -u UNIX-CONNECT:%t/hypr/\${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock OPEN:/dev/null";
        Restart = "no";
        # socat returns 128 + SIGTERM when systemd stops the watcher.
        SuccessExitStatus = [ 143 ];
      };
    };
    systemd.user.services.sunshine = {
      wants = lib.mkForce [ ];
      partOf = lib.mkForce [ "sunshine-session.service" ];
      after = lib.mkForce [ "sunshine-session.service" ];
      bindsTo = [ "sunshine-session.service" ];
    };

    # The upstream module supplies uinput and udev rules. Render-node access
    # supports VA-API; video membership is set in base-configuration.nix.
    #
    # "uinput" is required for remote mouse/keyboard injection: hardware.uinput
    # emits 99-local.rules (GROUP="uinput"), which sorts after Sunshine's own
    # 60-sunshine.rules (GROUP="input"), so "input" membership alone is useless
    # and the redundant uaccess tag does not apply to this static misc node.
    users.users.${data.username}.extraGroups = [
      "render"
      "uinput"
    ];

    # Match the upstream Sunshine port offsets, excluding the HTTPS admin UI
    # (47990). Do not use openFirewall: that exposes these on every interface.
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [
        47984
        47989
        48010
      ];
      allowedUDPPorts = [
        47998
        47999
        48000
        48002
        48010
      ];
    };
  };
}
