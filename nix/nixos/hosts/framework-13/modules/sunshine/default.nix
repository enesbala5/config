# Existing-session remote desktop for Moonlight clients (issue #111).
{
  data,
  lib,
  pkgs,
  ...
}:
{
  services.sunshine = {
    enable = true;
    autoStart = false;
    openFirewall = false;

    # KMS works without the wlroots screencopy protocol. The upstream module
    # wraps Sunshine with CAP_SYS_ADMIN; it still runs as the graphical user.
    capSysAdmin = true;
    settings = {
      sunshine_name = "Framework 13";
      capture = "kms";
      encoder = "vaapi";
      address_family = "ipv4";
      upnp = "disabled";
      # Pair locally or through an SSH tunnel; never expose the admin UI.
      origin_web_ui_allowed = "pc";
    };
    applications.apps = [ { name = "Desktop"; } ];
  };

  # This host launches Hyprland directly, without UWSM or an active
  # graphical-session.target. Track the compositor's event socket instead.
  # The host Lua startup hook imports the session environment and starts this.
  systemd.user.services.sunshine-session = {
    description = "Track Sunshine's Hyprland session";
    wants = [ "sunshine.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat -u UNIX-CONNECT:%t/hypr/\${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock OPEN:/dev/null";
      Restart = "no";
    };
  };
  systemd.user.services.sunshine = {
    wants = lib.mkForce [ ];
    partOf = lib.mkForce [ "sunshine-session.service" ];
    after = lib.mkForce [ "sunshine-session.service" ];
    bindsTo = [ "sunshine-session.service" ];
  };

  # The upstream module supplies uinput and udev rules. Render-node access
  # supports VA-API; video membership is already set in base-configuration.nix.
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
}
