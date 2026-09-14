{
  config,
  lib,
  pkgs,
  data,
  hostname,
  ...
}:
lib.mkIf config.homeServer.incusAiAgent.enable {
  systemd.services.incus-ai-agent-backup = {
    enable = true;
    description = "Backup OpenHands AI Agent state to Cloudflare R2";
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      EnvironmentFile = config.age.secrets.ai-agent-backup-env.path;
      StateDirectory = "incus-ai-agent-backup";
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

      VM_NAME="${config.homeServer.incusAiAgent.vmName}"

      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "AI Agent backup failed on ${hostname}: $1" || true
      }

      if ! ${pkgs.incus}/bin/incus info "$VM_NAME" >/dev/null 2>&1; then
        notify_failure "VM $VM_NAME does not exist."
        exit 1
      fi

      # `incus list NAME` is a regex filter, not an exact match. Anchor it so a
      # sibling VM with a similar prefix cannot produce a false RUNNING result.
      STATUS="$(${pkgs.incus}/bin/incus list "^$VM_NAME$" --format csv -c s)"
      if [ "$STATUS" != "RUNNING" ]; then
        notify_failure "VM $VM_NAME is not running (status: $STATUS)."
        exit 1
      fi

      if ! ${pkgs.incus}/bin/incus exec "$VM_NAME" -- true >/dev/null 2>&1; then
        notify_failure "Incus agent not reachable on $VM_NAME."
        exit 1
      fi

      # Warn but do not abort if the dir is missing — the agent may not
      # have written any conversations yet on a fresh VM.
      if ! ${pkgs.incus}/bin/incus exec "$VM_NAME" -- test -d /root/.openhands; then
        notify_failure "/root/.openhands does not exist in $VM_NAME — nothing to back up."
        exit 1
      fi

      # Stable staging path so restic can match the previous snapshot by
      # host + path and perform a true incremental backup.
      TMP="$STATE_DIRECTORY/stage"
      ${pkgs.coreutils}/bin/rm -rf "$TMP"
      ${pkgs.coreutils}/bin/mkdir -p "$TMP"
      trap 'rm -rf "$TMP"' EXIT

      # Stream a tar from the guest to avoid recursive `incus file pull` dying on
      # unix sockets or live SQLite sidecars. Guest tar exit 1 = file changed
      # mid-read (acceptable); exit >= 2 is fatal.
      set +e
      set +o pipefail
      ${pkgs.incus}/bin/incus exec "$VM_NAME" -- \
        tar \
          --exclude='*.sock' \
          --exclude='*.db-wal' \
          --exclude='*.db-shm' \
          --warning=no-file-changed \
          --ignore-failed-read \
          -C /root -cf - .openhands \
        | ${pkgs.gnutar}/bin/tar -C "$TMP" -xf -
      pipe_status=("''${PIPESTATUS[@]}")
      guest_tar="''${pipe_status[0]:-0}"
      host_tar="''${pipe_status[1]:-0}"
      set -o pipefail
      set -e

      if [ "$host_tar" -ne 0 ] || [ "$guest_tar" -gt 1 ]; then
        notify_failure "Failed to archive /root/.openhands from $VM_NAME (guest tar=$guest_tar host tar=$host_tar)."
        exit 1
      fi

      SRC="$TMP/.openhands"
      if [ ! -d "$SRC" ]; then
        notify_failure "Archived tree did not contain .openhands/."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic backup --tag ai-agent --tag automated "$SRC"; then
        notify_failure "restic backup command returned non-zero."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 3; then
        notify_failure "restic forget --prune command returned non-zero."
        exit 1
      fi

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --path "$SRC" --latest 1 --json | ${pkgs.jq}/bin/jq -r '.[0].short_id')
      echo "Done. Snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.incus-ai-agent-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:30";
      Persistent = true;
      Unit = "incus-ai-agent-backup.service";
    };
  };
}
