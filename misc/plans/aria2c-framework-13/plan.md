# aria2 Download Manager Setup Plan for Framework-13

> Note: Inspired by https://jdheyburn.co.uk/blog/adding-aria2-download-manager/#creating-an-aria2-nixos-module

## Overview

Add aria2 download manager to the framework-13 laptop with AriaNg web UI for local use only.

### Components
- **aria2 daemon**: Running with RPC server on localhost:6800
- **AriaNg web UI**: Served via nginx on http://localhost:8080
- **Authentication**: Simple plaintext RPC password stored in config directory
- **Access**: Local only (no public exposure)

## Implementation Steps

### 1. Create aria2 password file
- Create directory: `tools/aria2/`
- Store RPC password in `tools/aria2/rpc-secret`
- This file will contain the plaintext password for RPC authentication

### 2. Configure aria2 service in default.nix
- Enable aria2 service
- Set RPC secret file path to `${data.configDirectory}/tools/aria2/rpc-secret`
- Configure to listen only on localhost (default behavior)
- Set download directory (default: `/home/${data.username}/Downloads`)
- Add aria2 settings:
  - RPC listen port: 6800 (default)
  - RPC listen interface: localhost only
  - Enable RPC

### 3. Add user to aria2 group
- Add `${data.username}` to the `aria2` group
- This grants file modification permissions to downloaded files

### 4. Set up nginx
- Enable nginx service
- Serve AriaNg static files from `${pkgs.ariang}/share/ariang` on localhost:8080
- Configure reverse proxy for `/jsonrpc` endpoint to `localhost:6800`
- No TLS needed since it's local only
- No authentication on nginx level (handled by aria2 RPC)

### 5. Access the web UI
- Open browser to: `http://localhost:8080`
- Configure AriaNg to connect to aria2 RPC:
  - Protocol: http
  - Host: localhost
  - Port: 6800
  - Interface: /jsonrpc
  - Secret: (base64 encoded password from rpc-secret file)

## Differences from Original Article

### Simplified for Local Use
- **No Caddy**: Using nginx instead (simpler for local-only setup)
- **No DNS/Domain**: Just localhost
- **No TLS certificates**: Not needed for local access
- **No Cloudflare**: Not exposing publicly

### Plaintext Password
- Stored in config directory as requested
- No agenix or secrets management
- File: `tools/aria2/rpc-secret`

### Port Configuration
- AriaNg Web UI: `http://localhost:8080`
- aria2 RPC: `http://localhost:6800/jsonrpc`

## Configuration Files Modified

1. `/home/e/config/nix/nixos/hosts/framework-13/default.nix`
   - Add aria2 service configuration
   - Add nginx service configuration
   - Add user to aria2 group

## Post-Installation Configuration

After running `nixos-rebuild switch`, configure AriaNg in the browser:

1. Navigate to: `http://localhost:8080/#!/settings/rpc/set/http/localhost/6800/jsonrpc/BASE64_PASSWORD`
2. Replace `BASE64_PASSWORD` with the base64-encoded version of your password:
   ```bash
   echo -n "your-password" | base64
   ```

## Usage

- Access web UI: `http://localhost:8080`
- Add downloads through the web interface
- Downloads will be saved to: `/home/${data.username}/Downloads` (or custom directory)
- Manage downloads, view progress, pause/resume through the web UI

## Benefits

- Background downloads with nice web UI
- Multi-protocol support (HTTP, HTTPS, FTP, BitTorrent, Metalink)
- Multi-source/multi-connection downloading
- Resume support for interrupted downloads
- Lightweight and efficient
