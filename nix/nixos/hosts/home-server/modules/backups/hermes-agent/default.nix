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
      pkgs.incus
      pkgs.jq
      pkgs.restic
      pkgs.unzip
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

      # `incus list NAME` is a regex filter, not an exact match. Without
      # anchors, a sibling like hermes-agent-btest makes STATUS become
      # $'RUNNING\nRUNNING' and this check fails.
      STATUS="$(${pkgs.incus}/bin/incus list "^$VM_NAME$" --format csv -c s)"
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

      # Stable staging path so restic can match the previous snapshot by
      # host + path and do a true incremental backup.
      TMP="$STATE_DIRECTORY/stage"
      ${pkgs.coreutils}/bin/rm -rf "$TMP"
      ${pkgs.coreutils}/bin/mkdir -p "$TMP"
      trap 'rm -rf "$TMP"' EXIT

      # Use `hermes backup` to produce the zip — it already knows what to
      # include/exclude (skips cache, bin, node, lsp, backups, etc.), which
      # is why its output is ~1 GB while a raw .hermes tar is ~3 GB.
      GUEST_ZIP="/tmp/hermes-backup-restic-stage.zip"
      if ! ${pkgs.incus}/bin/incus exec "$VM_NAME" -- \
          hermes backup -o "$GUEST_ZIP" -k 0; then
        notify_failure "hermes backup failed inside $VM_NAME."
        exit 1
      fi

      HOST_ZIP="$TMP/hermes-backup.zip"
      if ! ${pkgs.incus}/bin/incus file pull "$VM_NAME$GUEST_ZIP" "$HOST_ZIP"; then
        notify_failure "incus file pull of backup zip failed."
        exit 1
      fi

      # Remove zip from guest now that we have it on the host.
      ${pkgs.incus}/bin/incus exec "$VM_NAME" -- rm -f "$GUEST_ZIP" || true

      SRC="$TMP/extracted"
      ${pkgs.coreutils}/bin/mkdir -p "$SRC"
      if ! ${pkgs.unzip}/bin/unzip -q "$HOST_ZIP" -d "$SRC"; then
        notify_failure "Failed to unzip hermes backup archive."
        exit 1
      fi
      ${pkgs.coreutils}/bin/rm -f "$HOST_ZIP"

      if ! ${pkgs.restic}/bin/restic backup \
          --tag hermes-agent --tag automated \
          "$SRC"; then
        notify_failure "restic backup command returned non-zero."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget --prune --keep-last 1 --group-by "host,tags"; then
        notify_failure "restic forget --prune command returned non-zero."
        exit 1
      fi

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
