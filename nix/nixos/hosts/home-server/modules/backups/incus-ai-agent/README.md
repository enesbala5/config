# OpenHands AI Agent backup

The backup service lives entirely in [`default.nix`](./default.nix): the
`incus-ai-agent-backup` oneshot + daily timer streams a tar of the two
stateful directories out of the `byok-agent` Incus VM via `incus exec … tar`,
extracts it to a stable host staging path, and stores the result in
Cloudflare R2 with restic.

**What gets backed up (from inside the VM)**

| Path | Contents |
|---|---|
| `/root/.openhands/` | Conversation history, agent settings, API keys/secrets, MCP config |

Unix sockets and live SQLite sidecars (`*.db-wal`, `*.db-shm`) are excluded
from the tar. The workspace (`/var/lib/ai-agent/workspace`) is intentionally
not backed up — it is ephemeral agent output (cloned repos, installed packages,
build artefacts) that balloons to several GB and is not needed for disaster
recovery.

- **Repository:** `rclone:r2:backups/ai-agent` (set via `RESTIC_REPOSITORY` in the env secret)
- **Creds:** agenix secret `ai-agent-backup-env` → `/run/agenix/ai-agent-backup-env`
  (`RESTIC_PASSWORD`, `RESTIC_REPOSITORY`), plus the shared rclone config at
  `/run/agenix/rclone-conf`.

---

## 1. Restore a snapshot to the host

Run as `root` (`sudo -i`):

```bash
source /run/agenix/ai-agent-backup-env
export RCLONE_CONFIG="/run/agenix/rclone-conf"

# Optional: list snapshots and pick one instead of `latest`.
restic snapshots --tag ai-agent

DEST="$HOME/ai-agent-restore"
mkdir -p "$DEST"
restic restore latest --target "$DEST"
```

The extracted tree mirrors the staging layout used during backup:

```
$DEST/var/lib/incus-ai-agent-backup/stage/.openhands/
```

## 2. Push state back into the VM

Stop the services first so nothing is writing while you restore:

```bash
VM=byok-agent   # or byok-agent-restore-test for a mock run
DEST="$HOME/ai-agent-restore"
SRC="$DEST/var/lib/incus-ai-agent-backup/stage/.openhands"

incus exec "$VM" -- systemctl stop openhands-agent-server openhands-agent-canvas || true

tar -C "$(dirname "$SRC")" -cf - .openhands \
  | incus exec "$VM" -- tar -C /root -xf -

incus exec "$VM" -- systemctl start openhands-agent-server openhands-agent-canvas
incus exec "$VM" -- ls -la /root/.openhands
```

## 3. Restoring to a freshly rebuilt VM

If the VM is gone, recreate it first via the standard launch process so
cloud-init installs OpenHands. Then run sections 1–2 above; the empty state
directories the fresh VM ships get replaced by the restore.

## 4. Testing with a mock VM

Use a throwaway VM so the live `byok-agent` is never touched.

> **Stop the production VM first** if the `byok-agent` profile pins the same
> IP (`10.0.100.173`) — a second VM using that profile cannot start while the
> live instance holds the address.

```bash
# Bring up a temporary test VM, restore into it, then tear it down.
incus launch ubuntu:24.04 byok-agent-restore-test
# ... restore (sections 1–2, using VM=byok-agent-restore-test) ...
incus delete --force byok-agent-restore-test
```

## Notes

- Need a fresh snapshot before restoring?

  ```bash
  systemctl start incus-ai-agent-backup.service
  journalctl -u incus-ai-agent-backup -n 80 --no-pager
  ```

- The timer runs at **04:30** (offset from hermes-agent's 03:00 to avoid
  R2 write contention).
- Retention: 7 daily, 4 weekly, 3 monthly snapshots.
