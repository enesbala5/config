# Garage backups — what’s needed on your end

Nix modules and `secrets.nix` entries are already in place. Remaining work is secrets, cloud credentials, repo init, and a one-time Garage bring-up on home-server.

---

## 1. Restic passwords

Generate two strong passwords (local + cloud). You need them for:

1. Filling the `.age` env files below
2. Running `restic init` (and any later restore)

Prefer a **different** restic password for each repo. Store both somewhere durable (password manager). Without them, backups are unrecoverable. Do not commit plaintext passwords.

---

## 2. Backblaze B2 (cloud repo)

Create (or reuse) and note:

| Item | Notes |
| --- | --- |
| Bucket | Dedicated or shared; path suffix `/garage` in `RESTIC_REPOSITORY` |
| Region / endpoint | Must match the bucket (e.g. `s3.eu-central-003.backblazeb2.com`) |
| Application Key ID | Maps to `AWS_ACCESS_KEY_ID` |
| Application Key | Maps to `AWS_SECRET_ACCESS_KEY` |

Key should allow read/write/list/delete on that bucket (enough for `restic backup`, `forget --prune`, and restores).

---

## 3. Secrets to create (agenix)

Both files are listed in `nix/secrets/secrets.nix` but **do not exist yet** under `nix/secrets/`. Create them from that directory:

```bash
manage-secret garage-backup-local-env.age
manage-secret garage-backup-cloud-env.age
```

### `garage-backup-local-env.age`

```bash
RESTIC_REPOSITORY=/mnt/seagate-512-hdd/backups/garage
RESTIC_PASSWORD=<strong unique password>
```

### `garage-backup-cloud-env.age`

```bash
RESTIC_REPOSITORY=s3:s3.<region>.backblazeb2.com/<bucket>/garage # Ignore this as we're using rclone, backblaze already configured
RESTIC_PASSWORD=<strong unique password>
AWS_ACCESS_KEY_ID=<b2 application key id>
AWS_SECRET_ACCESS_KEY=<b2 application key>
# Optional if restic needs it forced:
# AWS_DEFAULT_REGION=<region>
```

> Use the bucket’s real B2 region in the endpoint (plan example: `eu-central-003`).

---

## 4. One-time ops on home-server (after secrets land)

Order matters:

1. **Commit / pull** the new `.age` files into the config repo on home-server.
2. **`nixos-rebuild switch`** so agenix decrypts the env files and Garage + backup units exist.
3. **Init Garage cluster** (once):

   ```bash
   ~/config/scripts/hosts/home-server/garage-s3/init.sh
   ```

   Then save S3 credentials from:

   ```bash
   sudo garage key info main-app-key
   ```

4. **Init both restic repos** (with the matching env loaded, e.g. via the decrypted secret paths or a temporary `export` of the same vars):

   ```bash
   # Local
   restic init   # RESTIC_REPOSITORY=/mnt/seagate-512-hdd/backups/garage

   # Cloud
   restic init   # RESTIC_REPOSITORY=s3:... + AWS_* set
   ```

5. **Smoke-test** each unit once:

   ```bash
   sudo systemctl start backup-garage-local.service
   sudo systemctl start backup-garage-cloud.service
   # then: journalctl -u backup-garage-local -u backup-garage-cloud -e
   ```

Confirm timers:

```bash
systemctl list-timers 'backup-garage-*'
```

---

## 5. Already assumed present (no new setup unless broken)

- Toshiba 4TB mounted at `/mnt/hdd` (cold + S3 paths created by the Garage module tmpfiles).
- Telegram notify at `~/.config/tools/telegram/notify.sh` (failure alerts; same pattern as other home-server backups).
- User `enes` can read Garage data for restic (module already grants group access).

---

## Checklist

- [x] Strong `RESTIC_PASSWORD` for local repo (saved offline)
- [x] Strong `RESTIC_PASSWORD` for cloud repo (saved offline)
- [x] B2 bucket + region/endpoint
- [x] B2 application key ID + secret
- [x] Create `nix/secrets/garage-backup-local-env.age`
- [x] Create `nix/secrets/garage-backup-cloud-env.age`
- [ ] Deploy on home-server (`nixos-rebuild switch`)
- [ ] Run `garage-s3/init.sh`; store Garage `main-app-key` credentials
- [ ] Prepare 
	- [ ] `restic init` local path
	- [x] `restic init` B2
- [ ] Manual start + verify both backup units
