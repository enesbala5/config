# Hermes Agent restore

The backup itself lives entirely in [`default.nix`](./default.nix): the
`hermes-agent-backup` oneshot + daily timer stream `/root/.hermes` out of the
`hermes-agent` Incus VM and push it to Cloudflare R2 with restic. It is
implemented and tested, so this document only covers **restoring** and
**testing a restore**.

- **Repository:** `rclone:r2:backups/hermes-agent`
- **Creds:** agenix secret `hermes-agent-backup-env` →
  `/run/agenix/hermes-agent-backup-env` (`RESTIC_PASSWORD`,
  `RESTIC_REPOSITORY`), plus the shared rclone config at
  `/run/agenix/rclone-conf`.

## 1. Restore a snapshot to the host

Run as `root` (`sudo -i`) — the secret is root-owned (`0400`).

```bash
export RESTIC_PASSWORD="..."          # from /run/agenix/hermes-agent-backup-env
export RCLONE_CONFIG="/run/agenix/rclone-conf"

# Optional: list snapshots and pick one instead of `latest`.
restic -r rclone:r2:backups/hermes-agent snapshots --tag hermes-agent

# The snapshot stores an absolute path, so the tree lands nested under the
# target (this is expected).
restic -r rclone:r2:backups/hermes-agent restore latest \
  --target "$HOME/misc/to organize/test"
```

Result:

```
$HOME/misc/to organize/test/var/lib/hermes-agent-backup/stage/.hermes
```

## 2. Push the restored tree into the VM

Stop the Hermes services first (no live sockets / DB writers), keep a safety
copy of the current state, then tar-stream the tree in as `root`.

```bash
VM=hermes-agent
RESTORED="$HOME/misc/to organize/test/var/lib/hermes-agent-backup/stage/.hermes"

incus exec "$VM" -- systemctl stop hermes-agent hermes-dashboard hermes-serve
incus exec "$VM" -- bash -lc '
  rm -rf /root/.hermes.pre-restore
  mv /root/.hermes /root/.hermes.pre-restore 2>/dev/null || true
  mkdir -p /root/.hermes
'

tar -C "$(dirname "$RESTORED")" -cf - .hermes \
  | incus exec "$VM" -- tar -C /root -xf -
incus exec "$VM" -- chown -R root:root /root/.hermes
incus exec "$VM" -- chmod 700 /root/.hermes

incus exec "$VM" -- systemctl start hermes-agent hermes-dashboard hermes-serve
incus exec "$VM" -- ls -la /root/.hermes
```

Spot-check a known file (a skill or the memory DB) against the snapshot, then
drop the safety copy once satisfied:

```bash
incus exec "$VM" -- rm -rf /root/.hermes.pre-restore
```

## 3. Restoring to a freshly rebuilt VM

If the VM is gone, recreate it first. `hermes-vm-manage.sh` builds it from the
incus profile (cloud-init installs Hermes), re-pushes `/etc/hermes-env` from
agenix, and installs `oh-start.sh` + the OpenHands skill:

```bash
tools/incus/hermes-vm-manage.sh start
```

Then run sections 1–2 above; the empty `/root/.hermes` the fresh VM ships gets
replaced by the snapshot.

## 4. Testing a restore with a mock VM

Use a throwaway VM so the live `hermes-agent` instance is never touched. The
script can drive a differently-named VM with `--vm-name` (default
`hermes-agent`).

> **Stop the production VM before building a mock from the real profile.** The
> `hermes-agent` profile pins IP `10.0.100.174` and carries the
> `fwd-tcp-9119` proxy device, so a second VM built from it cannot start while
> the live VM holds that address:
>
> ```
> Error: Failed to start device "fwd-tcp-9119": Connect IP "10.0.100.174"
> must be one of the instance's static IPv4 addresses
> ```
>
> Either bring the live VM down first (`tools/incus/hermes-vm-manage.sh stop`),
> or build the mock with `--profile default` (no pinned IP, no proxy device).

### Option A — profile-less mock

No Hermes install, no secrets, no IP conflict. Works while production stays up.

```bash
MOCK=hermes-restore-test
incus launch images:ubuntu/24.04/cloud "$MOCK" --vm --profile default
until incus exec "$MOCK" -- true >/dev/null 2>&1; do sleep 2; done

# RESTORED is from section 1. The mock has no services, so skip section 2's
# systemctl stop/start — just drop the tree in.
incus exec "$MOCK" -- mkdir -p /root/.hermes
tar -C "$(dirname "$RESTORED")" -cf - .hermes \
  | incus exec "$MOCK" -- tar -C /root -xf -

# Diff it against production, ignoring the live sockets and SQLite sidecars
# the backup deliberately skips.
mkdir -p /tmp/prod-hermes
incus exec hermes-agent -- \
  tar --exclude='*.sock' --exclude='*.db-wal' --exclude='*.db-shm' \
      -C /root -cf - .hermes \
  | tar -C /tmp/prod-hermes -xf -
diff -r /tmp/prod-hermes/.hermes "$RESTORED"

incus stop "$MOCK" && incus delete "$MOCK"
rm -rf /tmp/prod-hermes
```

### Option B — manage-script mock

Exercises the real profile and cloud-init install, but needs the live VM
stopped first (shared pinned IP):

```bash
tools/incus/hermes-vm-manage.sh --vm-name hermes-restore-test start
# ...restore (sections 1–2, using VM=hermes-restore-test)...
tools/incus/hermes-vm-manage.sh --vm-name hermes-restore-test stop
tools/incus/hermes-vm-manage.sh start   # bring production back
```

## Notes

- The backup service reads its own env file, so exporting `RESTIC_PASSWORD` in
  your shell does not affect scheduled runs.
- Need a fresh snapshot before restoring?

  ```bash
  systemctl start hermes-agent-backup.service
  journalctl -u hermes-agent-backup -n 80 --no-pager
  ```
