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

Before running the install script, you'll need the SSH private key used to decrypt agenix secrets.

> Note: This step can be skipped as long the [secrets.nix](./nix/secrets/secrets.nix) has been updated with new SSH keys & secrets (`.age` files) recreated via agenix. More at "Secret Management".

1. Retrieve key from password manager, eg. "Agenix SSH - Framework 13 - e User"
2. Copy it to `~/.ssh/id_ed25519`
3. Set the correct permissions:

```bash
chmod 600 ~/.ssh/id_ed25519
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

Rclone frequently modifies the configuration file so making the config file read-only is not possible.
The file should be stored in `tools/rclone/rclone.conf` - as that's where existing services look for it.

In order to have rclone be fully functional, we need to decrypt the configuration first. If you have successfully installed the system, you can run:

```bash
decrypt-rclone-conf
```

Otherwise, if this doesn't work, run:

```bash
cd ~/config/nix/secrets && agenix --decrypt rclone-conf.age > ~/config/tools/rclone/rclone.conf
```

To test if the config was passed correctly, run:

```bash
cat ~/config/tools/rclone/rclone.conf
```

> Rebuilding the system might be necessary in order to ensure that systemd services use the updated configuration.

##### Updating the Rclone Configuration

If you need to update the rclone-configuration, run:

```bash
manage-secret rclone-conf.age
```

Alternatively:

```bash
cd ~/config/nix/secrets && EDITOR='zeditor --wait' agenix -e rclone-conf.age
```

**After you finish updating the configuration, run `decrypt-rclone-conf` to update the local rclone configuration file.**

## Hosts

### Framework 13

#### Audio Setup

In order to have good audio, we need to install Easyeffects (configured through Nix) and also the [Framework DSP](https://github.com/cab404/framework-dsp).

Run the installation steps detailed in the "Installing" section of the README (in the framework-dsp) repository.

Once that is completed, the profile "HifiScan+EEGuide" should be automatically selected on startup.

## Secret Management

Secret management is handled by [Agenix](https://github.com/ryantm/agenix). In order to update existing secrets, run `manage-secret <secret-name>`.
Creating new secrets is done by adding a new entry to [secrets.nix](./nix/secrets/secrets.nix) and then running `manage-secret <secret-name>`.

> You can reference secrets in your Nix configuration using `<secret-name>` without the `.age` extension.

Note: Secrets are not accessible in the Nix configuration at [nixos](./nix/nixos/) until they've been committed to the repository.

## Tools

### RClone

Service management commands:

- **`rclone-status`** - View service status (real-time)
- **`rclone-logs`** - Follow service logs
- **`rclone-start`** - Start service (timer, path watcher, service)
- **`rclone-stop`** - Stop service
- **`rclone-resync`** - Full resync (stops service, prompts confirmation, restarts) ⚠️

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
