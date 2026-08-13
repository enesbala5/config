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

  # FSD if on battery and voltage stays below 11.5 V for ~30s (empty-under-load, not fake %).
  nutLowVoltageWatch = pkgs.writeShellScript "nut-low-voltage-watch" ''
    set -u
    UPSC="${pkgs.nut}/bin/upsc"
    UPSMON="${pkgs.nut}/bin/upsmon"
    AWK="${pkgs.gawk}/bin/awk"
    GREP="${pkgs.gnugrep}/bin/grep"
    SLEEP="${pkgs.coreutils}/bin/sleep"
    below=0
    while true; do
      status=$($UPSC makelsan ups.status 2>/dev/null || true)
      volt=$($UPSC makelsan battery.voltage 2>/dev/null || true)
      if echo "$status" | $GREP -q OB \
        && $AWK -v v="$volt" 'BEGIN { exit !(v+0 > 0 && v+0 < 11.5) }'; then
        below=$((below + 1))
        if [ "$below" -ge 6 ]; then
          $UPSMON -c fsd || true
          below=0
          $SLEEP 30
        fi
      else
        below=0
      fi
      $SLEEP 5
    done
  '';

  nutUpsschedConf = pkgs.writeText "upssched.conf" ''
    CMDSCRIPT ${nutTelegramNotify}
    PIPEFN /run/nut/upssched.pipe
    LOCKFN /run/nut/upssched.lock

    # Debounce brief flickers: only notify if still on battery after 10s.
    AT ONBATT * START-TIMER onbatt-notify 10
    AT ONLINE * CANCEL-TIMER onbatt-notify
    AT ONLINE * EXECUTE online-notify
    # Worn packs lose runtime; 7 min leaves margin for shutdown+killpower on a tired 650VA.
    AT ONBATT * START-TIMER fsd-onbatt 420
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

        # NixOS ups-killpower runs after halt, so offdelay only needs a short ACPI gap.
        # Megatec: <60s in 6s steps, >=60s in 60s steps. ondelay is minutes; <3 min often never returns.
        "offdelay = 30"
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

  # upsdrv is oneshot and otherwise fails once if the 0001:0000 HID device
  # enumerates after the unit has already run (cable/socket swap, slow USB).
  systemd.services.upsdrv = {
    startLimitIntervalSec = 300;
    startLimitBurst = 30;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  systemd.services.ups-low-voltage-watch = {
    description = "FSD if Makelsan battery voltage stays below 11.5V on battery";
    after = [ "upsmon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = nutLowVoltageWatch;
      Restart = "always";
      RestartSec = "10s";
      User = config.power.ups.upsmon.user;
      Group = config.power.ups.upsmon.group;
    };
  };

  # upssched (nutmon) must create PIPEFN/LOCKFN here; NixOS leaves /run/nut root:root 0755.
  systemd.tmpfiles.rules = [
    "d /run/nut 0770 root ${config.power.ups.upsmon.group} -"
  ];
}
