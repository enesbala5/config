{
  config,
  pkgs,
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
      local text="$1"
      local code
      code=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" -m 10 -X POST \
        "https://api.telegram.org/bot''${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=''${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=''${text}" \
        --data-urlencode "parse_mode=Markdown" || true)
      if [ "$code" != "200" ]; then
        ${pkgs.curl}/bin/curl -s -o /dev/null -m 10 -X POST \
          "https://api.telegram.org/bot''${TELEGRAM_BOT_TOKEN}/sendMessage" \
          --data-urlencode "chat_id=''${TELEGRAM_CHAT_ID}" \
          --data-urlencode "text=''${text}" || true
      fi
    }

    ups_field() {
      ${pkgs.nut}/bin/upsc makelsan "$1" 2>/dev/null || echo "?"
    }

    case "''${1:-}" in
      onbatt-notify)
        notify "⚡ *Home Server on UPS power*
    🖥️ Host: ${hostname}
    🔋 Battery: $(ups_field battery.voltage) V
    🔌 Load: $(ups_field ups.load)%"
        ;;
      online-notify)
        notify "✅ *Mains power restored on ${hostname}*
    🖥️ UPS back on line power."
        ;;
      shutdown-notify)
        notify "🛑 *Home Server shutting down (UPS)*
    🖥️ Host: ${hostname}
    🔋 Battery: $(ups_field battery.voltage) V
    ⏱️ Soft shutdown starting — Restore-on-AC will reboot when power returns."
        ;;
      fsd-onbatt)
        ${pkgs.nut}/bin/upsmon -c fsd || true
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
    # Voltage-based SoC sags under load (93%→50% in ~1 min). Time-box instead of ignorelb@40%.
    AT ONBATT * START-TIMER fsd-onbatt 480
    AT ONLINE * CANCEL-TIMER fsd-onbatt
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
        # hunnox (not snr) is required for shutdown/killpower on this 0001:0000 chip (NUT HCL #2991).
        "subdriver = hunnox"
        "protocol = megatec"
        "langid_fix = 0x0409"
        "noscanlangid"
        "novendor"
        "norating"
        "allow_killpower"

        # Megatec rounds these to 60s steps; ondelay must stay > offdelay after rounding.
        # 120s covers a slow nixos/docker shutdown; 180s is the next step so Restore-on-AC sees a real gap.
        "offdelay = 120"
        "ondelay = 180"

        # Voltage→charge is display-only (sags under load). Do not use ignorelb on that number.
        "default.battery.voltage.high = 13.8"
        "default.battery.voltage.low = 11.0"
        "override.battery.packs = 1"
        "runtimecal = 300,100,900,50"
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

  # Telegram credentials for NUT notify (ONBATT / ONLINE / SHUTDOWN).
  systemd.services.upsmon.serviceConfig.EnvironmentFile =
    config.age.secrets.notify-server-boot-service-env.path;

  # upssched (nutmon) must create PIPEFN/LOCKFN here; NixOS leaves /run/nut root:root 0755.
  systemd.tmpfiles.rules = [
    "d /run/nut 0770 root ${config.power.ups.upsmon.group} -"
  ];
}
