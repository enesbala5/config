{
  config,
  pkgs,
  data,
  hostname,
  ...
}:
{
  systemd.services.db-backup-uptime-kuma = {
    enable = true;
    description = "Backup Uptime Kuma Database (on Hetzner VPS) to Cloudflare R2";
    after = [
      "network-online.target"
    ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      EnvironmentFile = config.age.secrets.uptime-kuma-database-backup-env.path;
    };
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "❌ *Uptime Kuma backup failed on ${hostname}*
      $1" || true
      }

      SSH_CFG="${config.age.secrets.home-server-ssh-config.path}"
      SSH_KEY="${config.age.secrets.amd-server-private-key.path}"
      REMOTE_TMP="/tmp/kuma.db"
      LOCAL_TMP="/tmp/kuma-backup.db"

      if [ -z "''${SSH_PASSPHRASE:-}" ]; then
        notify_failure "SSH_PASSPHRASE is not set in environment file."
        exit 1
      fi

      echo "Starting ssh-agent and unlocking key..."
      eval "$(${pkgs.openssh}/bin/ssh-agent -s)"
      trap 'kill "$SSH_AGENT_PID" 2>/dev/null || true; rm -f "$ASKPASS"' EXIT

      # sshpass often hangs under systemd; SSH_ASKPASS is the reliable path
      ASKPASS=$(${pkgs.coreutils}/bin/mktemp)
      ${pkgs.coreutils}/bin/chmod 700 "$ASKPASS"
      printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$SSH_PASSPHRASE"' > "$ASKPASS"

      echo "Adding key via SSH_ASKPASS..."
      if ! DISPLAY= SSH_ASKPASS_REQUIRE=force SSH_ASKPASS="$ASKPASS" \
        ${pkgs.coreutils}/bin/timeout 15 \
        ${pkgs.openssh}/bin/ssh-add "$SSH_KEY" </dev/null; then
        notify_failure "Failed to unlock SSH key within 15s (check SSH_PASSPHRASE)."
        exit 1
      fi
      echo "SSH key unlocked."

      # BatchMode fails fast instead of hanging if auth still needs a prompt
      SSH="${pkgs.openssh}/bin/ssh -F $SSH_CFG -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o BatchMode=yes"
      SCP="${pkgs.openssh}/bin/scp -F $SSH_CFG -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o BatchMode=yes"

      echo "Starting Uptime Kuma backup from hetzner-server..."
      echo "Resolving container name..."

      UK_CONTAINER=$($SSH hetzner-server \
        "docker ps --format '{{.Names}}' | grep '^uptime-kuma-' | head -n1")

      if [ -z "$UK_CONTAINER" ]; then
        notify_failure "Uptime Kuma container not found on hetzner-server."
        exit 1
      fi

      echo "Found container: $UK_CONTAINER"

      echo "Stopping container..."
      if ! $SSH hetzner-server "docker stop $UK_CONTAINER"; then
        notify_failure "Failed to stop container $UK_CONTAINER."
        exit 1
      fi

      echo "Copying database to remote temp..."
      if ! $SSH hetzner-server "docker cp $UK_CONTAINER:/app/data/kuma.db $REMOTE_TMP"; then
        $SSH hetzner-server "docker start $UK_CONTAINER" || true
        notify_failure "Failed to copy database from container."
        exit 1
      fi

      echo "Restarting container..."
      $SSH hetzner-server "docker start $UK_CONTAINER" || true

      echo "Downloading database..."
      if ! $SCP "hetzner-server:$REMOTE_TMP" "$LOCAL_TMP"; then
        notify_failure "Failed to download database from hetzner-server."
        exit 1
      fi

      $SSH hetzner-server "rm -f $REMOTE_TMP" || true

      BACKUP_SIZE=$(du -sh "$LOCAL_TMP" | cut -f1)
      echo "Downloaded ($BACKUP_SIZE), backing up with restic..."

      if ! ${pkgs.restic}/bin/restic backup \
        --tag uptime-kuma \
        --tag automated \
        "$LOCAL_TMP"; then
        notify_failure "restic backup command returned non-zero."
        rm -f "$LOCAL_TMP"
        exit 1
      fi

      if ! ${pkgs.restic}/bin/restic forget \
        --prune \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3; then
        notify_failure "restic forget --prune command returned non-zero."
        rm -f "$LOCAL_TMP"
        exit 1
      fi

      SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
        | ${pkgs.jq}/bin/jq -r '.[0].short_id')

      rm -f "$LOCAL_TMP"

      echo "Done. Snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.db-backup-uptime-kuma = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:30";
      Persistent = true;
      Unit = "db-backup-uptime-kuma.service";
    };
  };
}
