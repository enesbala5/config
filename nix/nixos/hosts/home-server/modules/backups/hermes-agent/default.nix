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
      EnvironmentFile = config.age.secrets.hermes-agent-backup-env.path;
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

      STATUS="$(${pkgs.incus}/bin/incus list "$VM_NAME" --format csv -c s)"
      if [ "$STATUS" != "RUNNING" ]; then
        notify_failure "VM $VM_NAME is not running (status: $STATUS)."
        exit 1
      fi

      if ! ${pkgs.incus}/bin/incus exec "$VM_NAME" -- true >/dev/null 2>&1; then
        notify_failure "Incus agent not reachable on $VM_NAME."
        exit 1
      fi

      if ! ${pkgs.incus}/bin/incus exec "$VM_NAME" -- test -d /root/.hermes; then
        notify_failure "/root/.hermes does not exist in $VM_NAME."
        exit 1
      fi

      TMP="$(${pkgs.coreutils}/bin/mktemp -d)"
      trap 'rm -rf "$TMP"' EXIT

      # Recursive `incus file pull` dies on unix sockets (gateway.sock while
      # the gateway is running). Stream a tar instead and skip sockets.
      # Guest tar exit 1 means a file changed mid-read (live state.db); that
      # is acceptable. Exit >= 2 is fatal.
      set +e
      set +o pipefail
      ${pkgs.incus}/bin/incus exec "$VM_NAME" -- \
        tar --exclude='*.sock' --warning=no-file-changed -C /root -cf - .hermes \
        | ${pkgs.gnutar}/bin/tar -C "$TMP" -xf -
      guest_tar=''${PIPESTATUS[0]}
      host_tar=''${PIPESTATUS[1]}
      set -o pipefail
      set -e
      if [ "$host_tar" -ne 0 ] || [ "$guest_tar" -gt 1 ]; then
        notify_failure "Failed to archive /root/.hermes from $VM_NAME (guest tar=$guest_tar host tar=$host_tar)."
        exit 1
      fi

      SRC="$TMP/.hermes"
      if [ ! -d "$SRC" ]; then
        notify_failure "Archived tree did not contain .hermes/."
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
