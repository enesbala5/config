{
  config,
  pkgs,
  data,
  hostname,
  ...
}:
{
  systemd.services.db-backup-coverlttr = {
    enable = true;
    description = "Backup Coverlttr Database to Cloudflare R2";
    after = [
      "network-online.target"
      "docker.service"
    ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = data.username;
      Group = "users";
      WorkingDirectory = "${data.homeDirectory}/dev/coverlttr/";
      EnvironmentFile = config.age.secrets.coverlttr-database-backup-env.path;
    };
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "❌ *Coverlttr database backup failed on ${hostname}*
      $1" || true
      }

      BACKUP_FILE="coverlttr-db.sql.gz"

      if ! ${pkgs.docker}/bin/docker compose \
        --env-file .env --env-file .env.prod \
        -f docker-compose.yaml -f docker-compose.prod.yaml \
        exec -T database pg_dumpall -U admin \
        | ${pkgs.gzip}/bin/gzip -9c > "$BACKUP_FILE"; then
        notify_failure "Failed to dump and compress PostgreSQL backup."
        exit 1
      fi

      BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
      echo "Dump complete ($BACKUP_SIZE), backing up with restic..."

      if ! ${pkgs.restic}/bin/restic backup \
        --tag coverlttr \
        --tag automated \
        "$BACKUP_FILE"; then
        notify_failure "restic backup command returned non-zero."
        rm -f "$BACKUP_FILE"
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget \
        --prune \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3; then
        notify_failure "restic forget --prune command returned non-zero."
        rm -f "$BACKUP_FILE"
        exit 1
      fi

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
        | ${pkgs.jq}/bin/jq -r '.[0].short_id')

      rm -f "$BACKUP_FILE"

      echo "Done. Snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.db-backup-coverlttr = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "02:30";
      Persistent = true;
      Unit = "db-backup-coverlttr.service";
    };
  };
}
