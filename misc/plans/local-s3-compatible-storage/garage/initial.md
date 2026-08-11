# Garage S3 NixOS Deployment & Backup Plan

This document outlines the step-by-step implementation plan and Nix code required to run Garage S3 on NixOS with a dual-drive layout (SSD for metadata, 4TB HDD for data) and dual `restic` backups:

- **Local** — restic repo on the Toshiba 4TB HDD (`/mnt/hdd/cold/backups/garage`)
- **Cloud** — restic repo on remote S3 (Backblaze B2), every 24 hours

Modules are **host-scoped** under `nix/nixos/hosts/home-server/modules/garage/` (not shared `nix/nixos/modules/`), since Garage and the HDD layout are home-server specific.

---

## Layout

```
nix/nixos/hosts/home-server/modules/garage/
├── default.nix           # daemon + directory layout; imports backup/*
├── backup/
│   ├── local.nix         # restic → /mnt/hdd/cold/backups/garage
│   └── cloud.nix         # restic → Backblaze B2 (S3), daily
```

Import only the folder from the host entrypoint (`./modules/garage` → `default.nix`).

---

## Task Checklist

- [ ] **Step 1:** Create `nix/nixos/hosts/home-server/modules/garage/default.nix` (daemon + dual-disk layout + backup imports).
- [ ] **Step 2:** Create `backup/local.nix` and `backup/cloud.nix`; add age secrets for each restic env.
- [ ] **Step 3:** Import `./modules/garage` in `nix/nixos/hosts/home-server/default.nix` and apply via `nixos-rebuild switch`.
- [ ] **Step 4:** Run initial Garage cluster layout assignment and key generation (`scripts/init-garage.sh`).
- [ ] **Step 5:** `restic init` both repos (local path + B2), then verify one manual run of each backup unit.

---

## 1. Garage module (`modules/garage/default.nix`)

```nix
# nix/nixos/hosts/home-server/default.nix
{
  imports = [
    ./modules/garage
  ];

  # ... existing home-server config ...
}
```

```nix
# nix/nixos/hosts/home-server/modules/garage/default.nix
{ config, pkgs, lib, data, ... }:

{
  imports = [
    ./backup/local.nix
    ./backup/cloud.nix
  ];

  # Directory layout for home-server drives (see drive/usecase notes).
  #
  # Current mounts (hardware-configuration.nix):
  #   /              — Samsung 970 EVO Plus 500GB (system SSD)
  #   /mnt/hdd       — Toshiba N300 4TB (bulk: S3, NAS, media, cold)
  #
  # Not mounted yet (do NOT add tmpfiles for these until fileSystems exist,
  # or dirs are created on the SSD root):
  #   /mnt/hdd-256   — Seagate 256GB ST9250827AS (scratch / stream cache)
  #   /mnt/hdd-512   — Seagate 512GB external (offline backup target, nofail)
  systemd.tmpfiles.rules = [
    # --- SSD (root): Garage metadata only (small, latency-sensitive) ---
    "d /var/lib/garage/meta 0700 garage garage -"

    # --- Toshiba 4TB @ /mnt/hdd ---
    # S3 (Garage) — Merre images, Coverlttr files
    "d /mnt/hdd/s3 0750 garage garage -"
    "d /mnt/hdd/s3/garage 0750 garage garage -"
    "d /mnt/hdd/s3/garage/data 0700 garage garage -"

    # NAS — Samba share root (migrate services.samba "private" path here)
    "d /mnt/hdd/nas 0755 ${data.username} users -"

    # Media / torrents — audiobooks + occasional movies (completed library)
    "d /mnt/hdd/media 0755 ${data.username} users -"
    "d /mnt/hdd/media/audiobooks 0755 ${data.username} users -"
    "d /mnt/hdd/media/movies 0755 ${data.username} users -"
    "d /mnt/hdd/media/torrents 0755 ${data.username} users -"

    # Cold storage — archives + local restic backup of Garage
    "d /mnt/hdd/cold 0750 ${data.username} users -"
    "d /mnt/hdd/cold/archives 0750 ${data.username} users -"
    "d /mnt/hdd/cold/backups 0750 ${data.username} users -"
    "d /mnt/hdd/cold/backups/garage 0700 ${data.username} users -"

    # --- Future: Seagate 256GB @ /mnt/hdd-256 (after fileSystems entry) ---
    # Scratch + Stremio/torrent incomplete — keep write wear off SSD + 4TB
    # "d /mnt/hdd-256/scratch 0755 ${data.username} users -"
    # "d /mnt/hdd-256/stremio-cache 0755 ${data.username} users -"
    # "d /mnt/hdd-256/torrent-incomplete 0755 ${data.username} users -"

    # --- Future: Seagate 512GB external @ /mnt/hdd-512 (nofail) ---
    # Optional second local restic target once mounted:
    # "d /mnt/hdd-512/backups 0750 ${data.username} users -"
    # "d /mnt/hdd-512/backups/garage 0700 ${data.username} users -"
  ];

  services.garage = {
    enable = true;
    package = pkgs.garage;

    settings = {
      # Local network binding
      s3_api = {
        s3_region = "garagenode";
        api_bind_addr = "127.0.0.1:3900";
        root_domain = ".s3.garage.localhost";
      };

      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";
      rpc_secret_file = "/var/lib/garage/rpc_secret";

      # Performance split: metadata on system SSD, bulk objects on 4TB HDD
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/mnt/hdd/s3/garage/data";

      db_engine = "lmdb";
      metadata_auto_snapshot_interval = "6h";
    };
  };

  # Service boot and network dependencies
  systemd.services.garage = {
    after = [ "network-online.target" "local-fs.target" ];
    wants = [ "network-online.target" ];
  };
}
```

---

## 2. Cluster Initialization Script (`scripts/init-garage.sh`)

Create a script to run once after rebuilding NixOS to initialize the node layout and keys:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> Fetching local Garage Node ID..."
NODE_ID=$(sudo garage status | grep -E '^[a-f0-9]{16}' | awk '{print $1}' | head -n 1)

if [ -z "$NODE_ID" ]; then
  echo "Error: Garage service is not running or node ID not found."
  exit 1
fi

echo "Found Node ID: $NODE_ID"

echo "==> Assigning capacity (4000G to 'local' zone)..."
sudo garage layout assign "$NODE_ID" --capacity 4000G --zone local

echo "==> Applying layout..."
sudo garage layout apply --version 1

echo "==> Creating default S3 access key..."
sudo garage key create main-app-key || true

echo "==> Initialization complete. Use 'sudo garage key info main-app-key' to retrieve S3 credentials."
```

---

## 3. Local backup (`modules/garage/backup/local.nix`)

Restic repo on the same Toshiba 4TB, under cold storage. No network dependency.

**Age secret:** `garage-backup-local-env.age` with at least:

```bash
RESTIC_REPOSITORY=/mnt/hdd/cold/backups/garage
RESTIC_PASSWORD=...
```

```nix
# nix/nixos/hosts/home-server/modules/garage/backup/local.nix
{ config, pkgs, ... }:

let
  data = {
    username = "enes";
    homeDirectory = "/home/enes";
    configDirectory = "/home/enes/.config";
  };
  hostname = config.networking.hostName;
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
      WorkingDirectory = "${data.homeDirectory}";
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
```

---

## 4. Cloud backup (`modules/garage/backup/cloud.nix`)

Restic to Backblaze B2 via the S3-compatible API. Runs every 24 hours.

**Age secret:** `garage-backup-cloud-env.age` with at least:

```bash
RESTIC_REPOSITORY=s3:s3.eu-central-003.backblazeb2.com/YOUR_BUCKET/garage
RESTIC_PASSWORD=...
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
# Optional if endpoint/region needs forcing:
# AWS_DEFAULT_REGION=eu-central-003
```

(Adjust endpoint/region to the B2 bucket’s actual region.)

```nix
# nix/nixos/hosts/home-server/modules/garage/backup/cloud.nix
{ config, pkgs, ... }:

let
  data = {
    username = "enes";
    homeDirectory = "/home/enes";
    configDirectory = "/home/enes/.config";
  };
  hostname = config.networking.hostName;
  source = "/mnt/hdd/s3/garage/data";
in
{
  systemd.services.backup-garage-cloud = {
    enable = true;
    description = "Backup Garage S3 data to Backblaze B2 (restic)";
    after = [
      "network-online.target"
      "garage.service"
    ];
    requires = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = data.username;
      Group = "users";
      WorkingDirectory = "${data.homeDirectory}";
      EnvironmentFile = config.age.secrets.garage-backup-cloud-env.path;
    };

    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail

      NotifyFailure() {
        ${data.configDirectory}/tools/telegram/notify.sh \
          "❌ *Garage cloud backup failed on ${hostname}*
      $1" || true
      }

      echo "Starting Garage → Backblaze B2 restic backup..."

      ${pkgs.garage}/bin/garage meta snapshot || true

      if ! ${pkgs.restic}/bin/restic backup \
        --tag garage \
        --tag cloud \
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

      echo "Done. Cloud snapshot: $SNAPSHOT"
    '';
  };

  systemd.timers.backup-garage-cloud = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
```

---

## 5. Secrets checklist

Add to `nix/secrets/secrets.nix` (same pattern as existing `*-database-backup-env.age`):

- `garage-backup-local-env.age`
- `garage-backup-cloud-env.age`

Wire both under `age.secrets` on the home-server host (or shared secrets map, matching existing backup env secrets).

---

## Notes

| Job | Destination | Schedule | Network |
| --- | --- | --- | --- |
| `backup-garage-local` | `/mnt/hdd/cold/backups/garage` on Toshiba 4TB | every 6h | no |
| `backup-garage-cloud` | Backblaze B2 (S3 API) | every 24h (`daily`) | yes |

Both back up the live Garage data dir `/mnt/hdd/s3/garage/data` after a best-effort `garage meta snapshot`.
