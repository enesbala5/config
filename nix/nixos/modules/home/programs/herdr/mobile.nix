{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.herdr;
  packages = pkgs.callPackage ./packages.nix { };
  # The desktop app's terminals live on herdr-core. The TUI is a different
  # socket, and Collie drives one of them per install.
  mux = if cfg.desktop.enable then "herdr-core" else "herdr";
in
{
  options.modules.home.herdr.mobile.enable = lib.mkEnableOption "Collie phone access";

  config = lib.mkIf (cfg.enable && cfg.mobile.enable) {
    home.packages = [ packages.collie ];

    # Loopback only. `collie serve` is the tailnet front door and is not run
    # here: on home-server, Tailscale HTTPS :443 is already Caddy's.
    systemd.user.services.collie = {
      Unit = {
        Description = "Collie (${mux})";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Install.WantedBy = [ "default.target" ];

      Service = {
        ExecStart = "${lib.getExe packages.collie} _exec-bridge";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "COLLIE_MUX=${mux}"
          "COLLIE_HOST=127.0.0.1"
          "COLLIE_PORT=8787"
          "DO_NOT_TRACK=1"
        ];
      };
    };
  };
}
