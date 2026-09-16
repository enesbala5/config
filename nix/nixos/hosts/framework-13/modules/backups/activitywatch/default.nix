{
  config,
  pkgs,
  lib,
  data,
  hostname,
  ...
}:
lib.mkIf (config.age.secrets ? activitywatch-backup-env) {
  systemd.services.backup-activitywatch = {
    enable = true;
    description = "Backup ActivityWatch data & configs with restic";
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = data.username;
      Group = "users";
      WorkingDirectory = data.homeDirectory;
      EnvironmentFile = config.age.secrets.activitywatch-backup-env.path;
    };
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      DATA_DIR="${data.homeDirectory}/.local/share/activitywatch"
      CONFIG_DIR="${data.homeDirectory}/.config/activitywatch"

      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "❌ *ActivityWatch backup failed on ${hostname}*
      $1" || true
      }

      if [ ! -d "$DATA_DIR" ]; then
        notify_failure "Data directory $DATA_DIR does not exist."
        exit 1
      fi

      if [ ! -d "$CONFIG_DIR" ]; then
        notify_failure "Config directory $CONFIG_DIR does not exist."
        exit 1
      fi

      # ActivityWatch keeps buckets and events in a live sqlite database, so
      # copying the raw files while the server runs can produce a torn database
      # that will not restore. Stage a consistent copy of every database with
      # sqlite3 .backup and exclude the live files from the snapshot.
      STAGE=$(mktemp -d)
      EXCLUDES=$(mktemp)
      trap 'rm -rf "$STAGE"; rm -f "$EXCLUDES"' EXIT

      DATABASES=$(find "$DATA_DIR" -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \))

      if [ -z "$DATABASES" ]; then
        notify_failure "No sqlite databases found under $DATA_DIR."
        exit 1
      fi

      echo "Found sqlite databases:"
      printf '%s\n' "$DATABASES"

      while IFS= read -r db; do
        rel="''${db#$DATA_DIR/}"
        mkdir -p "$STAGE/$(dirname "$rel")"
        if ! ${pkgs.sqlite}/bin/sqlite3 "$db" ".timeout 30000" ".backup '$STAGE/$rel'"; then
          notify_failure "Failed to snapshot $db."
          exit 1
        fi
        printf '%s\n' "$db" "$db-wal" "$db-shm" >> "$EXCLUDES"
      done <<< "$DATABASES"

      if ! ${pkgs.restic}/bin/restic backup \
        --tag activitywatch \
        --tag automated \
        --exclude-file "$EXCLUDES" \
        "$STAGE" "$CONFIG_DIR" "$DATA_DIR"; then
        notify_failure "restic backup command returned non-zero."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget \
        --prune \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3; then
        notify_failure "restic forget --prune command returned non-zero."
        exit 1
      fi

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
        | ${pkgs.jq}/bin/jq -r '.[0].short_id')

      rm -rf "$STAGE"
      rm -f "$EXCLUDES"

      echo "Done. Snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.backup-activitywatch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "02:45";
      Persistent = true;
      Unit = "backup-activitywatch.service";
    };
  };
}
