# Hermes Agent restore

The backup itself lives entirely in [`default.nix`](./default.nix): the
`hermes-agent-backup` oneshot + daily timer runs `hermes backup` inside the
`hermes-agent` Incus VM, pulls the resulting zip to the host, extracts it, and
stores the tree in Cloudflare R2 with restic. This document covers
**restoring** and **testing a restore**.

- **Repository:** `rclone:r2:backups/hermes-agent`
- **Creds:** agenix secret `hermes-agent-backup-env` →
  `/run/agenix/hermes-agent-backup-env` (`RESTIC_PASSWORD`,
  `RESTIC_REPOSITORY`), plus the shared rclone config at
  `/run/agenix/rclone-conf`.

## 1. Restore a snapshot to the host

Run as `root` (`sudo -i`) — the secret is root-owned (`0400`).

```bash
source /run/agenix/hermes-agent-backup-env
export RCLONE_CONFIG="/run/agenix/rclone-conf"

# Optional: list snapshots and pick one instead of `latest`.
restic snapshots --tag hermes-agent

DEST="$HOME/hermes-restore"
mkdir -p "$DEST"
restic restore latest --target "$DEST"
cd "$DEST"
```

The extracted tree mirrors the staging path used during backup:

```
$DEST/var/lib/hermes-agent-backup/stage/extracted/
```

## 2. Re-zip and push into the VM

`hermes restore` expects a zip archive. Re-create one from the extracted tree,
push it into the VM, restore, then clean up.

```bash
VM=hermes-agent
EXTRACTED="$DEST/var/lib/hermes-agent-backup/stage/extracted"
ZIPFILE="/tmp/hermes-restore.zip"

(cd "$EXTRACTED" && zip -r "$ZIPFILE" .)

incus exec "$VM" -- systemctl stop hermes-agent hermes-dashboard hermes-serve

incus file push "$ZIPFILE" "$VM/tmp/hermes-restore.zip"
incus exec "$VM" -- hermes restore /tmp/hermes-restore.zip

incus exec "$VM" -- rm /tmp/hermes-restore.zip
rm "$ZIPFILE"

incus exec "$VM" -- systemctl start hermes-agent hermes-dashboard hermes-serve
incus exec "$VM" -- ls -la /root/.hermes
```

## 3. Restoring to a freshly rebuilt VM

If the VM is gone, recreate it first. `hermes-vm-manage.sh` builds it from the
incus profile (cloud-init installs Hermes), re-pushes `/etc/hermes-env` from
agenix, and installs `oh-start.sh` + the OpenHands skill:

```bash
tools/incus/hermes-vm-manage.sh start
```

Then run sections 1–2 above; the empty `/root/.hermes` the fresh VM ships gets
replaced by the restore.

## 4. Testing a restore with a mock VM

Use a throwaway VM so the live `hermes-agent` instance is never touched.

> **Stop the production VM before building a mock from the real profile.** The
> `hermes-agent` profile pins IP `10.0.100.174` and carries the
> `fwd-tcp-9119` proxy device, so a second VM built from it cannot start while
> the live VM holds that address:
>
> ```
> Error: Failed to start device "fwd-tcp-9119": Connect IP "10.0.100.174"
> must be one of the instance's static IPv4 addresses
> ```

```bash
tools/incus/hermes-vm-manage.sh --vm-name hermes-restore-test start
# ...restore (sections 1–2, using VM=hermes-restore-test)...
tools/incus/hermes-vm-manage.sh --vm-name hermes-restore-test stop
tools/incus/hermes-vm-manage.sh start   # bring production back
```

## Notes

- The backup service sources its own env file; sourcing it manually in your
  shell does not affect scheduled runs.
- Need a fresh snapshot before restoring?

  ```bash
  systemctl start hermes-agent-backup.service
  journalctl -u hermes-agent-backup -n 80 --no-pager
  ```
