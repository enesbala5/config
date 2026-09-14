{
  config,
  data,
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

      apiHostName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "hermes-api.enesbala.com";
        description = ''
          Optional second host that reverse-proxies the Hermes API on the
          hermes-agent VM. Set null to serve only the dashboard.
        '';
      };

      apiUpstream = lib.mkOption {
        type = lib.types.str;
        default = "10.0.100.174:8642";
        description = "Hermes API inside the hermes-agent VM.";
      };
    };

    # Browser front end for the byok-agent VM. Agent Canvas (the successor to
    # the legacy OpenHands GUI) runs frontend-only in the guest on its own port,
    # while the agent server API stays on 8000. `agent.enesbala.com` proxies the
    # frontend, and `agent-api.enesbala.com` proxies the API so a browser on the
    # tailnet can add it as a Canvas backend.
    agent = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Reverse-proxy agent.enesbala.com to the byok-agent frontend.";
      };

      hostName = lib.mkOption {
        type = lib.types.str;
        default = "agent.enesbala.com";
        description = "Host that serves the OpenHands Agent Canvas frontend.";
      };

      upstream = lib.mkOption {
        type = lib.types.str;
        default = "10.0.100.173:3000";
        description = ''
          Agent Canvas frontend inside the byok-agent VM (the
          incusAiAgent module's frontendPort, default 3000). Pin the guest NIC:
            incus config device set byok-agent eth0 ipv4.address=10.0.100.173
        '';
      };

      apiHostName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "agent-api.enesbala.com";
        description = ''
          Optional second host that reverse-proxies the byok-agent agent server
          API. The Canvas frontend is only a client, so the browser needs to
          reach the API too: add this URL in Manage Backends using the key in
          OH_SESSION_API_KEYS_0. Set null to serve only the frontend.
        '';
      };

      apiUpstream = lib.mkOption {
        type = lib.types.str;
        default = "10.0.100.173:8000";
        description = "Agent server (conversation runtime) inside byok-agent.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Custom-domain A records point at a Tailscale IP, so the Let's Encrypt
    # HTTP-01 challenge cannot reach us. DNS-01 can: it only needs the DNS
    # provider's API, so Cloudflare issues publicly-trusted certs for these
    # hosts. Browsers then accept them without installing Caddy's local CA.
    services.caddy = {
      enable = true;
      # Caddy doesn't ship the Cloudflare DNS plugin; build it in.
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-J89UH8YgEU/uUDtmRuoGkPzIcQrbbWk+k06gqj0t8ho=";
      };
      email = data.email;
      globalConfig = ''
        default_bind {$CADDY_BIND_ADDR}
        auto_https disable_redirects
        acme_dns cloudflare {env.CF_API_TOKEN}
      '';
      virtualHosts = lib.mkMerge [
        (lib.mkIf cfg.hermes.enable {
          ${cfg.hermes.hostName} = {
            listenAddresses = [ "{$CADDY_BIND_ADDR}" ];
            extraConfig = ''
              encode gzip
              reverse_proxy ${cfg.hermes.upstream} {
                header_up Host {host}
                header_up X-Forwarded-Proto {scheme}
                header_up X-Forwarded-Host {host}
                flush_interval -1
              }
            '';
          };
        })

        (lib.mkIf (cfg.hermes.enable && cfg.hermes.apiHostName != null) {
          ${cfg.hermes.apiHostName} = {
            listenAddresses = [ "{$CADDY_BIND_ADDR}" ];
            extraConfig = ''
              encode gzip
              reverse_proxy ${cfg.hermes.apiUpstream} {
                header_up Host {host}
                header_up X-Forwarded-Proto {scheme}
                header_up X-Forwarded-Host {host}
                flush_interval -1
              }
            '';
          };
        })

        (lib.mkIf cfg.agent.enable {
          # Bare `:80` matches every host on the bound address, so a raw
          # `curl http://<tailscale-ip>/` reaches the frontend with no DNS.
          ":80" = {
            extraConfig = ''
              reverse_proxy ${cfg.agent.upstream} {
                header_up Host {host}
                flush_interval -1
              }
            '';
          };

          ${cfg.agent.hostName} = {
            listenAddresses = [ "{$CADDY_BIND_ADDR}" ];
            extraConfig = ''
              encode gzip
              reverse_proxy ${cfg.agent.upstream} {
                header_up Host {host}
                header_up X-Forwarded-Proto {scheme}
                header_up X-Forwarded-Host {host}
                flush_interval -1
              }
            '';
          };
        })

        (lib.mkIf (cfg.agent.enable && cfg.agent.apiHostName != null) {
          ${cfg.agent.apiHostName} = {
            listenAddresses = [ "{$CADDY_BIND_ADDR}" ];
            extraConfig = ''
              encode gzip
              reverse_proxy ${cfg.agent.apiUpstream} {
                header_up Host {host}
                header_up X-Forwarded-Proto {scheme}
                header_up X-Forwarded-Host {host}
                flush_interval -1
              }
            '';
          };
        })
      ];
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
      # Env for Caddy: the runtime bind address (written by the oneshot) plus
      # the Cloudflare API token consumed by `acme_dns`. mkForce replaces the
      # NixOS module's single-file default with this explicit list.
      serviceConfig.EnvironmentFile = lib.mkForce [
        "/run/caddy/tailscale.env"
        config.age.secrets.caddy-cloudflare-env.path
      ];
      # Upstream sets RestartPreventExitStatus=1, which turns a one-shot bind
      # race into a permanent failure. With the wait oneshot this is mostly
      # redundant, but allow retries if Tailscale flaps during switch.
      serviceConfig.RestartPreventExitStatus = lib.mkForce [ ];
    };
  };
}
