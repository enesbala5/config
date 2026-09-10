{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homeServer.openHandsUi;
in
{
  options.homeServer.openHandsUi = {
    enable = lib.mkEnableOption "on-demand OpenHands Web UI via Caddy + Sablier at agent.enesbala.com";

    upstream = lib.mkOption {
      type = lib.types.str;
      default = "http://10.0.100.2:3000";
      description = "byok-agent OpenHands UI upstream (Incus/Tailscale IP:3000)";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "agent.enesbala.com";
    };

    sablierUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:10000";
    };

    sessionDuration = lib.mkOption {
      type = lib.types.str;
      default = "15m";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = [
      "homeServer.openHandsUi.enable is on: confirm Sablier can reach the byok-agent Docker engine before relying on agent.enesbala.com."
    ];

    environment.systemPackages = [ pkgs.caddy ];

    services.caddy = {
      enable = true;
      virtualHosts.${cfg.domain}.extraConfig = ''
        route {
          sablier ${cfg.sablierUrl} {
            group openhands-ui
            session_duration ${cfg.sessionDuration}
            dynamic {
              display_name "OpenHands Workspace"
              theme hacker-terminal
              refresh_frequency 2s
            }
          }
          reverse_proxy ${cfg.upstream}
        }
      '';
    };
  };
}
