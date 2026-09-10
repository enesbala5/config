{
  config,
  lib,
  pkgs,
  data,
  hostname,
  ...
}:
lib.mkIf config.homeServer.incusHermesAgent.enable {
  systemd.services.hermes-agent-backup = {
    enable = true;
    description = "Backup Hermes Agent ~/.hermes to Cloudflare R2";
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      EnvironmentFile = config.age.secrets.hermes-agent-backup-secrets.path;
    };
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.gnutar
      pkgs.incus
      pkgs.jq
      pkgs.restic
    ];
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      VM_NAME="${config.homeServer.incusHermesAgent.vmName}"

      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "Hermes ~/.hermes backup failed on ${hostname}: $1" || true
      }

      if ! ${pkgs.incus}/bin/incus info "$VM_NAME" >/dev/null 2>&1; then
        notify_failure "VM $VM_NAME does not exist."
        exit 1
      fi

      TMP="$(${pkgs.coreutils}/bin/mktemp -d)"
      trap 'rm -rf "$TMP"' EXIT

      if ! ${pkgs.incus}/bin/incus file pull --recursive "$VM_NAME/root/.hermes" "$TMP/"; then
        notify_failure "Failed to pull /root/.hermes from $VM_NAME."
        exit 1
      fi

      SRC="$TMP/.hermes"
      if [ ! -d "$SRC" ]; then
        SRC="$TMP/hermes"
      fi
      if [ ! -d "$SRC" ]; then
        notify_failure "Pulled tree did not contain .hermes/."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic backup --tag hermes-agent --tag automated "$SRC"; then
        notify_failure "restic backup command returned non-zero."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 3; then
        notify_failure "restic forget --prune command returned non-zero."
        exit 1
      fi

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json | ${pkgs.jq}/bin/jq -r '.[0].short_id')
      echo "Done. Snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.hermes-agent-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
      Unit = "hermes-agent-backup.service";
    };
  };
}
