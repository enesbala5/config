{
  config,
  lib,
  pkgs,
  inputs,
  system,
  data,
  ...
}:

let
  cfg = config.homeServer.heliumBrowserMcp;
  helium = inputs.helium-browser.packages.${system}.default;

  stateDir = "/var/lib/helium-browser";
  profileDir = "${stateDir}/profile";

  startScript = pkgs.writeShellScript "helium-browser-mcp-start" ''
    set -euo pipefail
    install -d -m 0755 \
      ${stateDir}/recordings \
      ${stateDir}/npm \
      ${stateDir}/config \
      ${stateDir}/cache \
      ${profileDir}

    deadline=$((SECONDS + 90))
    while (( SECONDS < deadline )); do
      if ${lib.getExe' pkgs.iproute2 "ip"} -4 addr show dev incusbr0 2>/dev/null \
        | ${lib.getExe pkgs.gnugrep} -q 'inet ${cfg.listenAddress}/'; then
        break
      fi
      sleep 1
    done
    if ! ${lib.getExe' pkgs.iproute2 "ip"} -4 addr show dev incusbr0 2>/dev/null \
      | ${lib.getExe pkgs.gnugrep} -q 'inet ${cfg.listenAddress}/'; then
      echo "incusbr0 is missing ${cfg.listenAddress}; refusing to bind MCP elsewhere" >&2
      exit 1
    fi

    exec npx -y @playwright/mcp@${cfg.playwrightMcpVersion} \
      --headless \
      --no-sandbox \
      --executable-path ${lib.getExe helium} \
      --user-data-dir ${profileDir} \
      --host ${lib.escapeShellArg cfg.listenAddress} \
      --port ${toString cfg.port} \
      --allowed-hosts ${lib.concatMapStringsSep " " lib.escapeShellArg cfg.allowedHosts} \
      --caps=testing,devtools,storage \
      --output-dir ${lib.escapeShellArg cfg.recordingsPath} \
      --save-session \
      --viewport-size=${toString cfg.video.width}x${toString cfg.video.height}
  '';

  shareScript = pkgs.writeShellScript "helium-browser-mcp-share" ''
    set -euo pipefail
    install -d -m 0755 -o ${data.username} -g users ${cfg.recordingsPath}
    attach=${data.configDirectory}/tools/incus/attach-helium-recordings.sh
    if [[ ! -x "$attach" ]]; then
      echo "missing $attach" >&2
      exit 0
    fi
    ${lib.concatMapStringsSep "\n" (name: ''
      HELIUM_RECORDINGS=${cfg.recordingsPath} "$attach" ${lib.escapeShellArg name} || \
        echo "warning: could not attach recordings to ${name}" >&2
    '') cfg.shareWith}
  '';
in
{
  options.homeServer.heliumBrowserMcp = {
    enable = lib.mkEnableOption "headless Helium + Playwright MCP on the host for agent VMs";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.100.1";
      description = ''
        Address on incusbr0. Guests reach MCP here. Not bound on a public NIC,
        and not loopback, so both VMs can dial it without a third guest.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8931;
    };

    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "*" ];
      description = ''
        Host header values Playwright MCP will accept. "*" disables the check.
        The listen address is still the only interface the socket binds.
      '';
    };

    playwrightMcpVersion = lib.mkOption {
      type = lib.types.str;
      default = "latest";
    };

    recordingsPath = lib.mkOption {
      type = lib.types.str;
      default = "${stateDir}/recordings";
      description = "Traces, webm, and auto-named screenshots. Mounted into the agent VMs.";
    };

    video = {
      width = lib.mkOption {
        type = lib.types.int;
        default = 1280;
      };
      height = lib.mkOption {
        type = lib.types.int;
        default = 720;
      };
    };

    shareWith = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "hermes-agent"
        "byok-agent"
      ];
      description = "Incus instance names that should see recordingsPath at the same path.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      helium
    ];

    systemd.services.helium-browser-mcp = {
      description = "Headless Helium via Playwright MCP (agent VMs)";
      after = [
        "network-online.target"
        "incus.service"
      ];
      wants = [
        "network-online.target"
        "incus.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.bash
        pkgs.nodejs
        pkgs.iproute2
        pkgs.gnugrep
        pkgs.coreutils
      ];
      environment = {
        HOME = stateDir;
        XDG_CONFIG_HOME = "${stateDir}/config";
        XDG_CACHE_HOME = "${stateDir}/cache";
        XDG_DATA_HOME = "${stateDir}/data";
        NPM_CONFIG_CACHE = "${stateDir}/npm";
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
        # Helium must not open the desk profile or a window on Hyprland.
        PLAYWRIGHT_MCP_HEADLESS = "true";
      };
      serviceConfig = {
        User = data.username;
        Group = "users";
        UMask = "0022";
        StateDirectory = "helium-browser";
        StateDirectoryMode = "0755";
        WorkingDirectory = stateDir;
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    systemd.services.helium-browser-mcp-share = {
      description = "Mount Helium recordings into the agent VMs";
      after = [
        "incus.service"
        "helium-browser-mcp.service"
      ];
      wants = [ "incus.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = shareScript;
      };
    };
  };
}
