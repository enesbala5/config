{
  config,
  pkgs,
  data,
  hostname,
  ...
}:

let
  source = "/mnt/hdd/s3/garage/data";
in
{
  systemd.services.backup-garage-local = {
    enable = true;
    description = "Backup Garage S3 data to local HDD (restic)";
    after = [
      "local-fs.target"
      "garage.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      User = data.username;
      Group = "users";
      SupplementaryGroups = [ "garage" ];
      WorkingDirectory = data.homeDirectory;
      EnvironmentFile = config.age.secrets.garage-backup-local-env.path;
    };

    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      NotifyFailure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "❌ *Garage local backup failed on ${hostname}*
      $1" || true
      }

      echo "Starting Garage → local HDD restic backup..."

      ${pkgs.garage}/bin/garage meta snapshot || true

      if ! ${pkgs.restic}/bin/restic backup \
        --tag garage \
        --tag local \
        --tag automated \
        "${source}"; then
        NotifyFailure "restic backup command returned non-zero."
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget \
        --prune \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3; then
        NotifyFailure "restic forget --prune command returned non-zero."
        exit 1
      fi

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
        | ${pkgs.jq}/bin/jq -r '.[0].short_id')

      echo "Done. Local snapshot: $SNAPSHOT"
    '';
  };

  # Local is cheap — run more often than cloud (every 6h).
  systemd.timers.backup-garage-local = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00/6:00:00";
      Persistent = true;
    };
  };
}
