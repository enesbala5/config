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
      StateDirectory = "hermes-agent-backup";
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

      # Stable staging path. restic matches the previous snapshot as its
      # parent by host + path, so a random mktemp dir made every run look like
      # a brand-new path ("no parent snapshot found"), forcing restic to re-read
      # and re-hash all files instead of doing a true incremental backup. It
      # also broke `restic snapshots --latest 1`, since that filters per path.
      TMP="$STATE_DIRECTORY/stage"
      ${pkgs.coreutils}/bin/rm -rf "$TMP"
      ${pkgs.coreutils}/bin/mkdir -p "$TMP"
      trap 'rm -rf "$TMP"' EXIT

      # Recursive `incus file pull` dies on unix sockets (gateway.sock while
      # the gateway is running). Stream a tar instead and skip sockets / live
      # SQLite sidecars. Guest tar exit 1 means a file changed mid-read; that
      # is acceptable. Exit >= 2 is fatal.
      # Bash 5.3+ clears PIPESTATUS after any assignment, so capture once.
      set +e
      set +o pipefail
      ${pkgs.incus}/bin/incus exec "$VM_NAME" -- \
        tar \
          --exclude='*.sock' \
          --exclude='*.db-wal' \
          --exclude='*.db-shm' \
          --warning=no-file-changed \
          --ignore-failed-read \
          -C /root -cf - .hermes \
        | ${pkgs.gnutar}/bin/tar -C "$TMP" -xf -
      pipe_status=("''${PIPESTATUS[@]}")
      guest_tar="''${pipe_status[0]:-0}"
      host_tar="''${pipe_status[1]:-0}"
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

      # Filter by path: older snapshots exist under now-defunct random temp
      # paths, and `--latest 1` groups by path, so without this the newest one
      # returned would not necessarily be the snapshot we just created.
      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --path "$SRC" --latest 1 --json | ${pkgs.jq}/bin/jq -r '.[0].short_id')
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
