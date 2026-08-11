{ pkgs, data, ... }:

{
  imports = [
    ./backup/local.nix
    ./backup/cloud.nix
  ];

  # Static user: NixOS garage module defaults to DynamicUser, which conflicts with
  # durable ownership of /mnt/hdd/s3/... and the rpc_secret file.
  users.users.garage = {
    isSystemUser = true;
    group = "garage";
    home = "/var/lib/garage";
    createHome = true;
  };
  users.groups.garage = { };

  # Allow the interactive user to read Garage data for restic backups.
  users.users.${data.username}.extraGroups = [ "garage" ];

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
    # 0750 so members of group garage (incl. backup user) can read for restic
    "d /mnt/hdd/s3 0750 garage garage -"
    "d /mnt/hdd/s3/garage 0750 garage garage -"
    "d /mnt/hdd/s3/garage/data 0750 garage garage -"

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
      # Single-node cluster
      replication_factor = 1;

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

  # Service boot and network dependencies; pin static user + seed rpc secret
  systemd.services.garage = {
    after = [
      "network-online.target"
      "local-fs.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      DynamicUser = false;
      User = "garage";
      Group = "garage";
      ExecStartPre = [
        "+${pkgs.writeShellScript "garage-ensure-rpc-secret" ''
          set -euo pipefail
          secret=/var/lib/garage/rpc_secret
          if [ ! -f "$secret" ]; then
            umask 077
            ${pkgs.openssl}/bin/openssl rand -hex 32 > "$secret"
          fi
          chown garage:garage "$secret"
          chmod 0400 "$secret"
        ''}"
      ];
    };
  };
}
