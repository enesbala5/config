{
  config,
  lib,
  ...
}:

let
  cfg = config.homeServer.caddy;
in
{
  options.homeServer.caddy = {
    enable = lib.mkEnableOption "Tailscale-only Caddy front for Incus agent UIs";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "100.88.203.12";
      description = ''
        Address Caddy binds. Must be the home-server Tailscale IPv4 so Coolify
        can keep 127.0.0.1:80/443. Do not use 0.0.0.0.
      '';
    };

    hermes = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Reverse-proxy hermes.enesbala.com to the Hermes dashboard";
      };

      hostName = lib.mkOption {
        type = lib.types.str;
        default = "hermes.enesbala.com";
      };

      upstream = lib.mkOption {
        type = lib.types.str;
        default = "10.0.100.10:9119";
        description = ''
          Hermes dashboard inside the hermes-agent VM. Pin the guest NIC:
            incus config device set hermes-agent eth0 ipv4.address=10.0.100.10
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Custom-domain A records point at a Tailscale IP, so Let's Encrypt
    # HTTP-01 cannot reach us. Caddy's local CA is enough on the tailnet;
    # trust it once from the client (`caddy trust` / install root.crt).
    services.caddy = {
      enable = true;
      globalConfig = ''
        default_bind ${cfg.bindAddress}
        auto_https disable_redirects
      '';
      virtualHosts = lib.mkIf cfg.hermes.enable {
        ${cfg.hermes.hostName} = {
          listenAddresses = [ cfg.bindAddress ];
          extraConfig = ''
            tls internal
            encode gzip
            reverse_proxy ${cfg.hermes.upstream} {
              header_up Host {host}
              header_up X-Forwarded-Proto {scheme}
              header_up X-Forwarded-Host {host}
              flush_interval -1
            }
          '';
        };
      };
    };

    services.tailscale.permitCertUid = "caddy";

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      80
      443
    ];
  };
}
