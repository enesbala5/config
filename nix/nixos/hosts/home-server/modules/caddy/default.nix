{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homeServer.caddy;

  # Resolve (or pin) the Tailscale IPv4 and expose it to Caddy via env.
  # Coolify already owns 127.0.0.1:80/443, so Caddy must bind the tailnet
  # address only — never 0.0.0.0. Hardcoding that address in the Nix store
  # races with tailscaled and breaks when the node IP changes; Caddyfile
  # {$CADDY_BIND_ADDR} + a oneshot that waits for a bindable address is the
  # durable approach (caddy-tailscale/tsnet would also work but needs an
  # auth key and a custom Caddy build).
  resolveBindScript = pkgs.writeShellScript "caddy-resolve-tailscale-bind" ''
    set -euo pipefail
    mkdir -p /run/caddy
    wanted=${lib.escapeShellArg (if cfg.bindAddress == null then "" else cfg.bindAddress)}
    deadline=$((SECONDS + 90))
    while (( SECONDS < deadline )); do
      if ! ${lib.getExe' pkgs.iproute2 "ip"} link show dev tailscale0 >/dev/null 2>&1; then
        sleep 1
        continue
      fi
      ts_ip="$(${lib.getExe pkgs.tailscale} ip -4 2>/dev/null || true)"
      if [ -z "$ts_ip" ]; then
        sleep 1
        continue
      fi
      if [ -n "$wanted" ] && [ "$ts_ip" != "$wanted" ]; then
        echo "tailscale ip -4 is $ts_ip, expected $wanted" >&2
        sleep 1
        continue
      fi
      if ${lib.getExe' pkgs.iproute2 "ip"} -4 addr show dev tailscale0 | ${lib.getExe pkgs.gnugrep} -q "inet ''${ts_ip}/"; then
        printf 'CADDY_BIND_ADDR=%s\n' "$ts_ip" > /run/caddy/tailscale.env
        exit 0
      fi
      sleep 1
    done
    echo "timed out waiting for bindable Tailscale IPv4''${wanted:+ (wanted $wanted)}" >&2
    exit 1
  '';
in
{
  options.homeServer.caddy = {
    enable = lib.mkEnableOption "Tailscale-only Caddy front for Incus agent UIs";

    bindAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "100.88.203.12";
      description = ''
        Optional pin for the address Caddy binds. null (default) uses
        `tailscale ip -4` at service start. Set this only when DNS must match
        a specific Tailscale IPv4 — Caddy still waits until that address is
        present on tailscale0. Must not be 0.0.0.0 (Coolify keeps
        127.0.0.1:80/443).
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
        default = "10.0.100.174:9119";
        description = ''
          Hermes dashboard inside the hermes-agent VM. Pin the guest NIC:
            incus config device set hermes-agent eth0 ipv4.address=10.0.100.174
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
      # Written by caddy-tailscale-bind before caddy starts.
      environmentFile = "/run/caddy/tailscale.env";
      globalConfig = ''
        default_bind {$CADDY_BIND_ADDR}
        auto_https disable_redirects
      '';
      virtualHosts = lib.mkIf cfg.hermes.enable {
        ${cfg.hermes.hostName} = {
          listenAddresses = [ "{$CADDY_BIND_ADDR}" ];
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

    systemd.services.caddy-tailscale-bind = {
      description = "Wait for Tailscale IPv4 and write Caddy bind env";
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
      before = [ "caddy.service" ];
      requiredBy = [ "caddy.service" ];
      # Propagate caddy restarts so we re-resolve the IP (stale /run env otherwise).
      partOf = [ "caddy.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = resolveBindScript;
      };
    };

    systemd.services.caddy = {
      after = [
        "caddy-tailscale-bind.service"
        "tailscaled.service"
      ];
      requires = [ "caddy-tailscale-bind.service" ];
      # Upstream sets RestartPreventExitStatus=1, which turns a one-shot bind
      # race into a permanent failure. With the wait oneshot this is mostly
      # redundant, but allow retries if Tailscale flaps during switch.
      serviceConfig.RestartPreventExitStatus = lib.mkForce [ ];
    };
  };
}
