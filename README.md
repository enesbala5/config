# 📁 config

Self-contained NixOS system and workspace configuration repository.

## Overview

This repository houses the entire declarative environment for my machines. It is designed to be cloned directly to `~/config` and manages everything from core system hardware profiles to user-space tools and encrypted secrets.

## Design & Architecture

- **Declarative & reproducible:** The entire system is fully defined and reproducible across different hardware targets, like my Framework 13.
- **Secret management:** Secure, key-based credential handling integrated natively via Agenix.
- **Custom automation:** Handcrafted operational wrapper scripts to streamline background services like Rclone and Keymapper.

## Installation

### Preparing Secrets (Agenix)

Agenix decrypts secrets during system activation using the host's SSH key (`/etc/ssh/ssh_host_ed25519_key`). This key must be listed as a recipient in secrets.nix for every secret the host needs.

If setting up a new machine, get its host key (cat /etc/ssh/ssh_host_ed25519_key.pub), add it to secrets.nix (on a machine with host key already configured), and re-encrypt all secrets with `agenix -r` before committing changes & pushing to GitHub. Afterwards, the new machine should be able to decrypt secrets automatically on activation (after pulling changes from the remote).
Alternatively you can skip re-encrypting secrets and use an existing key instead, with the steps listed below:

1. Retrieve key from password manager, eg. "Agenix SSH (System) - Framework 13"
2. Rewrite `/etc/ssh/ssh_host_ed25519_key` with the retrieved key
3. Ensure the key has the correct permissions:

```bash
chmod 600 /etc/ssh/ssh_host_ed25519_key
```

### Fresh Install

```bash
./scripts/rebuild-switch.sh framework-13 --force
```

### Existing Install

```bash
nixos-rebuild-switch framework-13
```

> **Note:** Other useful commands include `nixos-rebuild-switch-logs`, `nixos-rebuild-test`.

### Post-Install

#### Rclone

Agenix secret `rclone-conf` is the source of truth (`/run/agenix/rclone-conf`).

- **CLI / static remotes** (r2, backblaze-b2, …): use `RCLONE_CONFIG=/run/agenix/rclone-conf` (set in session env).
- **Google Drive bisync** (framework-13): activation copies that secret to a writable `~/.config/rclone/rclone.conf` on every rebuild/boot so rclone can refresh OAuth tokens. The systemd unit and `rclone-resync` point at this file.

To verify after install/rebuild:

```bash
cat /run/agenix/rclone-conf
cat ~/.config/rclone/rclone.conf
```

##### Updating the Rclone Configuration

```bash
manage-secret rclone-conf.age
```

Alternatively:

```bash
cd ~/config/nix/secrets && EDITOR='zeditor --wait' agenix -e rclone-conf.age
```

Then rebuild — activation overwrites `~/.config/rclone/rclone.conf` from the updated secret.

## Hosts

### Home Server
The home server configuration provisions base system dependencies, firewall rules, and native storage points. Application-level services and environments are layered directly on top using the assets maintained in `./tools`.

#### Infrastructure Run-Steps
- **Coolify / Docker:** Container setups are kept in `./tools/coolify` and updated via the included `upgrade.sh` helper logic.
- **Incus:** Certificate at `./nix/nixos/hosts/home-server/certificates/incus` used to authenticate to Incus Web UI.
- **Production Backups:** Background maintenance workflows execute shell operations using encrypted variables parsed straight out of Agenix (e.g., database states for platforms like Audiobookshelf and custom web apps via restic / rclone).

### Framework 13

#### Audio Setup

In order to have good audio, we need to install Easyeffects (configured through Nix) and also the [Framework DSP](https://github.com/cab404/framework-dsp).

Run the installation steps detailed in the "Installing" section of the README (in the framework-dsp) repository.

Once that is completed, the profile "HifiScan+EEGuide" should be automatically selected on startup.


## Secret Management

Secret management is handled by [Agenix](https://github.com/ryantm/agenix). To edit or create secrets you need your **user key** (`~/.ssh/id_ed25519`) listed as a recipient in `secrets.nix` (or manually specify the identity file through `agenix -i`).

> Retrieve your user key from the password manager (e.g. *"Agenix SSH - Framework 13 - e User"*), copy it to `~/.ssh/id_ed25519`, and run `chmod 600 ~/.ssh/id_ed25519`.

To update an existing secret:

```bash
manage-secret <secret-name>
```

Or alternatively:

```bash
cd ~/config/nix/secrets && EDITOR='zeditor --wait' agenix -e # replace zeditor as needed
```

Creating new secrets: add an entry to [`secrets.nix`](./nix/secrets/secrets.nix), then run `manage-secret <secret-name>`.

> Secrets are not accessible in Nix configuration at [nixos](./nix/nixos/) until committed to the repository. Reference them without the `.age` extension - this applies to home-manager configs too.

## Tools

### RClone

Service management commands:

- **`rclone-status`** - View service status (real-time)
- **`rclone-logs`** - Follow service logs
- **`rclone-start`** - Start service (timer, path watcher, service)
- **`rclone-stop`** - Stop service
- **`rclone-resync`** - Full resync (stops service, prompts confirmation, restarts)

### Keymapper

Launch keymapper:

```bash
keymapper -c ~/config/tools/keymapper/configuration.conf
```

## Misc

### Nix Cache

To check if a specific Nix store path is available in a Cachix binary cache, you can use a simple curl command or specialized tools.

1. Check a Specific Path via HTTP
   Every cached path has a corresponding .narinfo file containing its metadata. You can check for its existence by using the store path's hash:

Run curl:

```bash
curl -I https://<your-cache-name>.cachix.org/<hash>.narinfo
```

> Hash can be the commit hash or the store path hash

Success (200 OK): The package is cached.
Failure (404 Not Found): The package is not in the cache.

## Other

Notes available [here](./misc/notes)
