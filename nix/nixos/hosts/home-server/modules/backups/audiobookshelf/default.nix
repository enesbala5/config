{
  config,
  pkgs,
  data,
  hostname,
  ...
}:
{
  systemd.services.db-backup-audiobookshelf = {
    enable = true;
    description = "Backup Audiobookshelf Config & Metadata to Cloudflare R2";
    after = [
      "network-online.target"
      "docker.service"
    ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      EnvironmentFile = config.age.secrets.audiobookshelf-database-backup-env.path;
    };
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "❌ *Audiobookshelf backup failed on ${hostname}*
      $1" || true
      }

      DATE=$(date '+%Y-%m-%d_%H-%M')

      echo "Starting Audiobookshelf backup: $DATE"

      ABS_CONTAINER=$(${pkgs.docker}/bin/docker ps --format '{{.Names}}' | grep audiobookshelf | head -n1)

      if [ -z "$ABS_CONTAINER" ]; then
        notify_failure "Audiobookshelf container not found."
        exit 1
      fi

      echo "Found container: $ABS_CONTAINER"

      CONFIG_PATH=$(${pkgs.docker}/bin/docker inspect "$ABS_CONTAINER" \
        --format '{{ range .Mounts }}{{ if eq .Destination "/config" }}{{ .Source }}{{ end }}{{ end }}')

      METADATA_PATH=$(${pkgs.docker}/bin/docker inspect "$ABS_CONTAINER" \
        --format '{{ range .Mounts }}{{ if eq .Destination "/metadata" }}{{ .Source }}{{ end }}{{ end }}')

      echo "Config path: $CONFIG_PATH"
      echo "Metadata path: $METADATA_PATH"

      echo "Stopping Audiobookshelf container..."

      if ! ${pkgs.docker}/bin/docker stop "$ABS_CONTAINER"; then
        notify_failure "Failed to stop container $ABS_CONTAINER."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic backup \
        --tag audiobookshelf \
        --tag automated \
        "$CONFIG_PATH" "$METADATA_PATH"; then
        ${pkgs.docker}/bin/docker start "$ABS_CONTAINER" || true
        notify_failure "restic backup command returned non-zero."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget \
        --prune \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3; then
        ${pkgs.docker}/bin/docker start "$ABS_CONTAINER" || true
        notify_failure "restic forget --prune command returned non-zero."
        exit 1
      fi

      echo "Starting Audiobookshelf container..."

      if ! ${pkgs.docker}/bin/docker start "$ABS_CONTAINER"; then
        notify_failure "Backup completed, but failed to restart container $ABS_CONTAINER."
        exit 1
      fi

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
        | ${pkgs.jq}/bin/jq -r '.[0].short_id')

      echo "Done. Snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.db-backup-audiobookshelf = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
      Unit = "db-backup-audiobookshelf.service";
    };
  };
}
