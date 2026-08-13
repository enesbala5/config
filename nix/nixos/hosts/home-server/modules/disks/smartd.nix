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

    if [ -z "''${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "''${TELEGRAM_CHAT_ID:-}" ]; then
      echo "smartd-telegram-notify: TELEGRAM_BOT_TOKEN/CHAT_ID not set; skipping" >&2
      exit 0
    fi

    ${data.configDirectory}/tools/telegram/notify.sh -m plain \
      "⚠️ smartd on ${hostname}
💾 Device: ''${SMARTD_DEVICESTRING:-unknown device}
🏷️ Type: ''${SMARTD_FAILTYPE:-alert}

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
    # -m -M exec: documented smartd hook; reminder cadence is diminishing
    defaults.monitored = "-a -n standby,q -m -M exec ${smartdTelegramNotify}";
  };

  systemd.services.smartd = {
    after = [
      "network-online.target"
      "local-fs.target"
    ];
    wants = [ "network-online.target" ];
  };
}
