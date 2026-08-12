{
  config,
  pkgs,
  data,
  hostname,
  ...
}:
let
  # Localhost-only upsd auth (not a network secret). Shared by upsd.users + upsmon.
  nutUpsmonPasswordFile = pkgs.writeText "nut-upsmon-password" "makelsan-local-upsmon-only";

  nutTelegramNotify = pkgs.writeShellScript "nut-telegram-notify" ''
    set -euo pipefail
    export PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gawk}/bin:$PATH"

    # TELEGRAM_* come from systemd.services.upsmon EnvironmentFile.
    if [ -z "''${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "''${TELEGRAM_CHAT_ID:-}" ]; then
      echo "nut-telegram-notify: TELEGRAM_BOT_TOKEN/CHAT_ID not set; skipping" >&2
      exit 0
    fi

    notify() {
      ${data.configDirectory}/tools/telegram/notify.sh "$1" || true
    }

    ups_charge() {
      ${pkgs.nut}/bin/upsc makelsan battery.charge 2>/dev/null || echo "?"
    }

    ups_runtime_msg() {
      local runtime
      runtime=$(${pkgs.nut}/bin/upsc makelsan battery.runtime 2>/dev/null || true)
      if [[ "$runtime" =~ ^[0-9]+$ ]]; then
        echo "~$((runtime / 60)) min remaining"
      else
        echo "runtime unknown"
      fi
    }

    case "''${1:-}" in
      onbatt-notify)
        notify "⚡ *Home Server on UPS power*
    🖥️ Host: ${hostname}
    🔋 Charge: $(ups_charge)%
    ⏱️ $(ups_runtime_msg)"
        ;;
      online-notify)
        notify "✅ *Mains power restored on ${hostname}*
    🖥️ UPS back on line power."
        ;;
      shutdown-notify)
        notify "🛑 *Home Server shutting down (UPS)*
    🖥️ Host: ${hostname}
    🔋 Charge: $(ups_charge)%
    ⏱️ Soft shutdown starting — Restore-on-AC will reboot when power returns."
        ;;
      *)
        echo "nut-telegram-notify: unknown event ''${1:-}" >&2
        exit 1
        ;;
    esac
  '';

  nutUpsschedConf = pkgs.writeText "upssched.conf" ''
    CMDSCRIPT ${nutTelegramNotify}
    PIPEFN /run/nut/upssched.pipe
    LOCKFN /run/nut/upssched.lock

    # Debounce brief flickers: only notify if still on battery after 10s.
    AT ONBATT * START-TIMER onbatt-notify 10
    AT ONLINE * CANCEL-TIMER onbatt-notify
    AT ONLINE * EXECUTE online-notify
    AT SHUTDOWN * EXECUTE shutdown-notify
    AT FSD * EXECUTE shutdown-notify
  '';
in
{
  # ------------------------------------------------------------------------------------------
  # Power / UPS (NUT)
  # ------------------------------------------------------------------------------------------

  power.ups = {
    enable = true;
    mode = "standalone";
    schedulerRules = "${nutUpsschedConf}";

    ups."makelsan" = {
      driver = "nutdrv_qx";
      port = "auto";
      description = "MAKELSAN Lion 650VA";
      directives = [
        "vendorid = 0001"
        "productid = 0000"
        # Empty USB strings make autodetection pick krauler and fail with "Device not supported".
        # Working combo for Makelsan Lion 0001:0000 (NUT HCL #2991).
        "subdriver = snr"
        "protocol = megatec"
        "langid_fix = 0x0409"
        "noscanlangid"
        "novendor"
        "norating"

        # Cut UPS output after shutdown so BIOS "Restore on AC" sees a real power loss.
        # offdelay must cover a full nixos shutdown (docker/coolify can be slow).
        "offdelay = 90"
        # Must be > offdelay; short gap is enough for the PSU/mobo to register disconnect.
        "ondelay = 100"

        # nutdrv_qx has no `lowbatt`; ignore the UPS LB flag and trip at 40% charge instead.
        # ~15 min runtime → 40% ≈ ~6 min left for graceful shutdown.
        "ignorelb"
        "override.battery.charge.low = 40"
      ];
    };

    users.upsmon = {
      passwordFile = "${nutUpsmonPasswordFile}";
      upsmon = "primary";
    };

    upsmon.monitor.makelsan = {
      system = "makelsan@localhost";
      user = "upsmon";
      passwordFile = "${nutUpsmonPasswordFile}";
      type = "primary";
    };

    upsmon.settings = {
      NOTIFYFLAG = [
        [
          "ONBATT"
          "SYSLOG+EXEC"
        ]
        [
          "ONLINE"
          "SYSLOG+EXEC"
        ]
        [
          "SHUTDOWN"
          "SYSLOG+EXEC"
        ]
        [
          "FSD"
          "SYSLOG+EXEC"
        ]
      ];
    };
  };

  # Telegram credentials for NUT → notify.sh (ONBATT / ONLINE / SHUTDOWN).
  systemd.services.upsmon.serviceConfig.EnvironmentFile =
    config.age.secrets.notify-server-boot-service-env.path;
}
