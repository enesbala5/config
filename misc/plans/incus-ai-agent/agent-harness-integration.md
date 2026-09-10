This implementation plan details the setup for **Hermes Agent** and **OpenHands**, featuring on-demand UI activation via **Sablier + Caddy** at `agent.enesbala.com`.

### System Architecture Overview

| Component | Host Environment | Lifecycle & Behavior |
| --- | --- | --- |
| **Hermes Agent** | `hermes-agent` VM

 | Always-on background daemon listening continuously on Telegram. Manages state, memories, and task orchestration.

 |
| **OpenHands Runtime** | `byok-agent` VM

 | Continuous warm VM holding git clones and dependencies in `/var/lib/ai-agent/workspace`. Executes headless tasks on demand.

 |
| **OpenHands Web UI** | `byok-agent` Docker Container | Scales to zero when idle. Managed on-demand by Sablier via host Caddy requests. |
| **Caddy + Sablier** | `home-server` Host | Reverse proxy handling HTTPS at `agent.enesbala.com`, intercepting requests to start/stop the UI container. |

---

### Step 1: OpenHands Container Configuration (`byok-agent` VM)

Inside the persistent `byok-agent` VM, configure the OpenHands Web UI container in `docker-compose.yml` with Sablier labels:

```yaml
version: '3.8'
services:
  openhands-ui:
    image: ghcr.io/all-hands-ai/openhands:latest
    container_name: openhands-ui
    ports:
      - "3000:3000"
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.12-nikola
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/ai-agent/workspace:/opt/workspace_base
    labels:
      - "sablier.enable=true"
      - "sablier.group=openhands-ui"
      - "sablier.ready-on-start=true"

```

---

### Step 2: Sablier & Caddy Setup (`nix/nixos/hosts/home-server/`)

Configure Caddy with the Sablier plugin alongside the Sablier daemon on `home-server`.

#### 1. Sablier Daemon Setup

Add Sablier to systemd or run it via Docker on `home-server`, exposing its API locally to Caddy (`[http://127.0.0.1:10000](http://127.0.0.1:10000)`) and granting access to the VM's Docker socket or host Docker daemon.

#### 2. NixOS Caddy Configuration

In `nix/nixos/hosts/home-server/modules/caddy.nix`:

```nix
{ pkgs, ... }:

{
  services.caddy = {
    enable = true;
    # Compile Caddy with the official Sablier middleware plugin
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/sablierapp/sablier/plugins/caddy@v1.8.0" ];
      hash = "sha256-0000000000000000000000000000000000000000000="; # Nix will prompt for true hash on first rebuild
    };

    virtualHosts."agent.enesbala.com".extraConfig = ''
      route {
        sablier http://127.0.0.1:10000 {
          group openhands-ui
          session_duration 15m
          dynamic {
            display_name "OpenHands Workspace"
            theme hacker-terminal
            refresh_frequency 2s
          }
        }
        reverse_proxy http://100.x.y.z:3000 # byok-agent VM Tailscale/Incus IP
      }
    '';
  };
}

```

---

### Step 3: Domain Routing & Security (`agent.enesbala.com`)

1. **Cloudflare DNS:** Create an **A Record** pointing `agent.enesbala.com` to your `home-server` Tailscale IP (`100.x.y.z`).
2. **Access Security:** Because the DNS record resolves to a private Tailscale IP, access is strictly restricted to devices authenticated on your Tailnet.
3. **SSL Certificate:** Caddy automatically provisions Let's Encrypt certificates via Cloudflare DNS challenge or Tailscale HTTPS.

---

### Step 4: End-to-End On-Demand Workflow

```
[Browser: agent.enesbala.com] ──► [Caddy + Sablier (home-server)]
                                           │
                        ┌──────────────────┴──────────────────┐
                 Container Stopped?                    Container Active?
                        │                                     │
           Displays "Waking Up..." UI                         │
           Calls Sablier API -> `docker start openhands-ui`   │
           Waits ~1.5s for port :3000 health check            │
                        │                                     │
                        └──────────────────┬──────────────────┘
                                           ▼
                       Reverse Proxy ──► [byok-agent:3000]

```

1. **Request Received:** You navigate to `[https://agent.enesbala.com](https://agent.enesbala.com)`.
2. **Container Activation:** If the container is stopped, Sablier holds the HTTP request, displays an auto-refreshing loading terminal screen, and triggers `docker start openhands-ui`.
3. **Session Hand-Off:** Once port `3000` responds, Caddy seamlessly redirects your browser tab into the running OpenHands Web UI.
4. **Auto-Idle Shut Down:** After 15 minutes of inactivity (`session_duration 15m`), Sablier executes `docker stop openhands-ui`. The underlying `byok-agent` VM remains warm and running in the background.


5. **Headless Hermes Trigger:** Unaffected by the Web UI state, Hermes can dispatch background coding jobs directly via `tools/incus/run-agent-task.sh` without waking the web frontend.