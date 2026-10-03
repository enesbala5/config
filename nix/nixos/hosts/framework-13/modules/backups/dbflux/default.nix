{
  config,
  pkgs,
  data,
  hostname,
  ...
}:
{
  systemd.services.db-backup-dbflux = {
    enable = true;
    description = "Backup DBFlux State to Cloudflare R2";
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = data.username;
      Group = "users";
      WorkingDirectory = data.homeDirectory;
      EnvironmentFile = config.age.secrets.dbflux-backup-env.path;
      Environment = [
        "HOME=${data.homeDirectory}"
        "XDG_CACHE_HOME=${data.homeDirectory}/.cache"
      ];
    };
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "❌ *DBFlux backup failed on ${hostname}*
      $1" || true
      }

      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/dbflux"
      DB="$DATA_DIR/dbflux.db"

      if [ ! -f "$DB" ]; then
        notify_failure "No database at $DB."
        exit 1
      fi

      # Stable staging path so restic matches the previous snapshot by host and
      # path, keeping the backup incremental.
      SRC="$HOME/.cache/dbflux-backup/stage"
      ${pkgs.coreutils}/bin/rm -rf "$SRC"
      ${pkgs.coreutils}/bin/mkdir -p "$SRC"

      # Online snapshot so the dump stays consistent while DBFlux is running.
      SNAPSHOT_DB="$SRC/dbflux.db"
      if ! ${pkgs.sqlite}/bin/sqlite3 "$DB" -cmd '.timeout 5000' ".backup '$SNAPSHOT_DB'"; then
        notify_failure "Failed to snapshot SQLite database."
        exit 1
      fi

      if ! ${pkgs.sqlite}/bin/sqlite3 "$SNAPSHOT_DB" .dump \
        | ${pkgs.gzip}/bin/gzip -9c > "$SRC/dbflux.sql.gz"; then
        notify_failure "Failed to dump SQLite database."
        exit 1
      fi
      ${pkgs.coreutils}/bin/rm -f "$SNAPSHOT_DB"

      if [ -d "$DATA_DIR/scripts" ]; then
        ${pkgs.rsync}/bin/rsync -a "$DATA_DIR/scripts/" "$SRC/scripts/"
      fi

      if ! ${pkgs.restic}/bin/restic backup \
        --tag dbflux \
        --tag automated \
        "$SRC"; then
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

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --path "$SRC" --latest 1 --json \
        | ${pkgs.jq}/bin/jq -r '.[0].short_id')

      ${pkgs.coreutils}/bin/rm -rf "$SRC"

      echo "Done. Snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.db-backup-dbflux = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "db-backup-dbflux.service";
    };
  };
}
