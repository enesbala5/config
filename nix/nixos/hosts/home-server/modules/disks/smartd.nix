{
  config,
  pkgs,
  lib,
  data,
  hostname,
  ...
}:
let
  # smartd -M exec gets a cleaned env (SMARTD_* only). Source telegram
  # credentials here — same secret as boot / UPS notifies.
  smartdTelegramNotify = pkgs.writeShellScript "smartd-telegram-notify" ''
    set -euo pipefail
    export PATH="${
      lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
      ]
    }:$PATH"

    envFile="${config.age.secrets.notify-server-boot-service-env.path}"

    if [ -f "$envFile" ]; then
      set -a
      source "$envFile"
      set +a
    fi

    # Persistent (not /var/tmp). Also check the old tmp path so acks
    # written before the move still suppress notifies.
    ackFiles="${data.homeDirectory}/.config/smartd/acknowledged /var/tmp/smartd-acknowledged"
    info="''${SMARTD_DEVICEINFO:-}"
    serial=""
    if [[ "$info" == *"S/N:"* ]]; then
      serial="''${info#*S/N:}"
    elif [[ "$info" == *"Serial Number:"* ]]; then
      serial="''${info#*Serial Number:}"
    fi
    serial="''${serial%%,*}"
    serial="$(printf '%s' "$serial" | tr -d '[:space:]')"

    failtype="''${SMARTD_FAILTYPE:-alert}"
    if [[ -n "$serial" ]]; then
      key="''${serial}:''${failtype}"
    else
      key="''${SMARTD_DEVICESTRING:-unknown}:''${failtype}"
    fi

    for ackFile in $ackFiles; do
      [[ -f "$ackFile" ]] || continue
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" == "$key" ]]; then
          echo "smartd-telegram-notify: $key acknowledged; skipping" >&2
          exit 0
        fi
      done < "$ackFile"
    done

    if [ -z "''${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "''${TELEGRAM_CHAT_ID:-}" ]; then
      echo "smartd-telegram-notify: TELEGRAM_BOT_TOKEN/CHAT_ID not set; skipping" >&2
      exit 0
    fi

    ${data.configDirectory}/tools/telegram/notify.sh -m plain \
      --button copy "$key" \
      "⚠️ smartd on ${hostname}
💾 Device: ''${SMARTD_DEVICESTRING:-unknown device}
🏷️ Type: ''${failtype}
🔑 ''${key}

''${SMARTD_FULLMESSAGE:-''${SMARTD_MESSAGE:-no message}}" \
      || echo "smartd-telegram-notify: telegram send failed (non-fatal)" >&2
  '';
in
{
  environment.systemPackages = [ pkgs.smartmontools ];

  services.smartd = {
    enable = true;
    # NVMe (Samsung 970 EVO Plus), SATA (Toshiba N300), USB when present
    # (Seagate GoFlex). DEVICESCAN at start — replug USB ⇒ restart smartd.
    autodetect = true;

    # Own notify via smartd -M exec (below). Leave NixOS mail/wall/x11 off
    # or they prepend a second -m -M exec.
    notifications = {
      mail.enable = false;
      wall.enable = false;
      x11.enable = false;
    };

    # -a: health, attributes, error + self-test logs
    # -n standby,q: do not spin up idle HDDs just to poll SMART
    # -m <nomailer> is required: otherwise -m consumes -M and "exec" is a syntax error
    defaults.monitored = "-a -n standby,q -m <nomailer> -M exec ${smartdTelegramNotify}";
  };

  systemd.services.smartd = {
    after = [
      "network-online.target"
      "local-fs.target"
    ];
    wants = [ "network-online.target" ];
  };
}
