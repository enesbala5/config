# Implementation Plan: Persistent Hermes Agent Incus VM

> **Companion to:** [`byok-chat-delegation.md`](../incus-ai-agent/byok-chat-delegation.md) (persistent BYOK coding-agent VM running OpenCode/OpenHands). That plan covers task-scoped coding work; this one covers the always-on personal-agent layer — memory, skills, reminders, messaging channels, and social monitoring. They are separate Incus VMs by design (see Security notes).
>
> **Tracks:** a new GitHub issue in `enesbala5/config` (propose title/body at the end — link it to #31 as related infra work).

## **Objective**

Run a **persistent, always-on** Incus VM on `home-server` hosting [Hermes Agent](https://github.com/NousResearch/hermes-agent) — a BYOK personal-agent runtime with cross-session memory, self-writing skills, MCP tools, terminal/browser automation, natural-language scheduling (reminders), and messaging-channel integration (Telegram to start; Discord/Slack/WhatsApp optional later).

Unlike the coding-agent VM, Hermes is not task-triggered — it's a long-running service that listens on its messaging channels and accumulates state (memory, skills) over its lifetime. The persistence model is therefore **backup-and-restore**, not **golden-snapshot-and-reset**: you never want to wipe Hermes's memory, only recover from a broken toolchain while keeping `~/.hermes/` intact.

LLM usage is billed to BYOK keys (OpenRouter primary, so model choice stays flexible; optional direct Anthropic/OpenAI-compatible keys) stored in age secrets. Reuses the same host patterns as the rest of `home-server`: Telegram notify via `tools/telegram/notify.sh`, agenix secret injection, Incus profile/limits, restic+rclone backups to R2.

The feature is a **toggleable, host-scoped NixOS module** under `nix/nixos/hosts/home-server/modules/`, independent of `incus-ai-agent`, so either can be enabled/disabled without affecting the other.

**Out of scope for v1:** wiring Hermes's coding/PR work to delegate into the separate `byok-agent` VM (Hermes has its own terminal/git tools and can do this directly — cross-VM delegation is a later optimization, not required). Also out of scope: Discord/Slack/WhatsApp channels (Telegram only for v1; others are additive config, not architecture changes).

---

## **Why a separate VM from `byok-agent`**

| | `byok-agent` (OpenCode/OpenHands) | `hermes-agent` (this plan) |
| --- | --- | --- |
| Lifecycle | Warm but idle between tasks; triggered per task | Always running; listens on messaging channels continuously |
| State that matters | Repo clones, package caches (disposable, re-cloneable) | `~/.hermes/` memory DB + skills (irreplaceable, accumulated over time) |
| Recovery model | Restore golden snapshot, re-run task | Backup/restore `~/.hermes/`, keep OS layer disposable |
| Attack surface | Executes LLM-generated shell/code per task | Same, *plus* always-listening messaging bot tokens, ongoing browser automation for social monitoring |
| Blast radius if compromised | One task's credentials (GitHub PAT) | Every channel token + everything in accumulated memory |

Sharing a VM would mean a compromised coding task and a compromised long-running personal agent share a credential/network boundary. Keep them apart — the marginal Incus VM cost is a few GB of idle RAM, not worth collapsing this boundary for.

---

## **File Structure & Deliverables**

```
nix/nixos/hosts/home-server/
├── default.nix                              # import ./modules/incus-hermes-agent (gated by enable)
└── modules/incus-hermes-agent/
    └── default.nix                          # toggleable module: profile, age secret wire-up, backup timer

nix/secrets/
├── secrets.nix                              # register hermes-agent-secrets.age
└── hermes-agent-secrets.age                 # user-encrypted env (manual manage-secret)

tools/incus/
├── hermes-vm-manage.sh                      # host entrypoint: start/stop/status/logs/backup/restore
└── hermes-backup.sh                         # restic+rclone backup of ~/.hermes/ (called by systemd timer)

# Inside guest (via cloud-init / profile user-data):
#   /usr/local/bin/notify.sh
#   ~/.hermes/                                # memory, skills, config — the durable payload
```

**Naming:**

| Concept | Name |
| --- | --- |
| Module dir | `modules/incus-hermes-agent/` |
| Module option | `homeServer.incusHermesAgent.enable` |
| Incus profile | `hermes-agent` |
| Persistent VM name | `hermes-agent` |
| Age secret file | `hermes-agent-secrets.age` → `/run/agenix/hermes-agent-secrets` |
| Host scripts | `tools/incus/hermes-vm-manage.sh`, `tools/incus/hermes-backup.sh` |

---

## **Step 1: Secrets Schema (`nix/secrets/hermes-agent-secrets.age`)**

```bash
manage-secret hermes-agent-secrets.age
```

```env
# Required — model provider (OpenRouter keeps model choice flexible)
OPENROUTER_API_KEY="sk-or-..."

# Optional direct providers (Hermes supports 200+ models across these)
ANTHROPIC_API_KEY=""
OPENAI_API_KEY=""

# Telegram — this is Hermes's own bot, not just the notify.sh channel.
# Create a dedicated bot via @BotFather; do not reuse the host's ops bot.
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHI..."
TELEGRAM_ALLOWED_USERS="your_telegram_user_id"

# Git (fine-grained PAT: contents + PRs on repos Hermes should touch directly)
GITHUB_TOKEN="ghp_..."

# Host-ops notify channel (reuses tools/telegram/notify.sh pattern for
# start/stop/health messages — separate from the Hermes bot above)
OPS_TELEGRAM_BOT_TOKEN="987654321:XYZ..."
OPS_TELEGRAM_CHAT_ID="987654321"

# Backup target (reuse existing R2 rclone remote, new path)
RESTIC_REPOSITORY="rclone:r2:backups/hermes-agent"
RESTIC_PASSWORD="..."
```

Register in `nix/secrets/secrets.nix` with `rootConfig`:

```nix
"hermes-agent-secrets.age" = rootConfig;
```

> Keep `TELEGRAM_BOT_TOKEN` (Hermes's own channel) and `OPS_TELEGRAM_BOT_TOKEN` (host notify script) as two distinct bots. If Hermes's memory or a skill ever gets exfiltrated via prompt injection, you don't want that same token also controlling your ops notifications.

---

## **Step 2: Toggleable NixOS Module (`modules/incus-hermes-agent/default.nix`)**

### 2.1 Import + enable gate

```nix
imports = [
  ./modules/incus-ai-agent
  ./modules/incus-hermes-agent
];
```

```nix
{ config, lib, pkgs, data, ... }:

let
  cfg = config.homeServer.incusHermesAgent;
in
{
  options.homeServer.incusHermesAgent = {
    enable = lib.mkEnableOption "persistent Hermes Agent Incus VM (profile + backup timer)";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-agent";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-agent";
    };

    limits = {
      cpu = lib.mkOption { type = lib.types.str; default = "2"; };
      memory = lib.mkOption { type = lib.types.str; default = "4GiB"; };
    };

    backup = {
      enable = lib.mkEnableOption "daily restic backup of ~/.hermes to R2" // { default = true; };
      onCalendar = lib.mkOption { type = lib.types.str; default = "daily"; };
    };
  };

  config = lib.mkIf cfg.enable {
    # Merge hermes-agent profile into virtualisation.incus.preseed.profiles
    # (append alongside existing profiles — do not replace default).
    #
    # If cfg.backup.enable: systemd.timers/services on the HOST that run
    # tools/incus/hermes-backup.sh on cfg.backup.onCalendar, sourcing
    # /run/agenix/hermes-agent-secrets for RESTIC_REPOSITORY/RESTIC_PASSWORD
    # and `incus file pull` on ~/.hermes before running restic (see Step 5).
  };
}
```

Lower resource footprint than `byok-agent` (2 vCPU / 4GiB default) since Hermes isn't compiling/running heavy sandboxed builds itself — bump if browser automation for social monitoring proves memory-hungry in practice.

### 2.2 Incus profile — persistent, always-running VM

Cloud-init packages:

- `git`, `curl`, `jq`, `ca-certificates`
- `chromium` or `playwright`'s bundled browser deps (for Hermes's browser-automation tool) — check Hermes docs at implement time for the exact dependency list, install via their setup script rather than hand-picking packages where possible
- `python3`/`nodejs` only if Hermes's install script requires them (prefer the official `curl | bash`-style installer over manually replicating its dependency tree)

Injected via cloud-init `write_files`:

1. `/usr/local/bin/notify.sh` — from host `tools/telegram/notify.sh`, wired to `OPS_TELEGRAM_BOT_TOKEN`/`OPS_TELEGRAM_CHAT_ID` (host-ops channel, not the Hermes bot itself).
2. A systemd unit (`hermes-agent.service`) in the guest that runs `hermes start` (or whatever the daemonized entrypoint is — confirm exact command in Hermes docs) with `Restart=on-failure`, `EnvironmentFile=/etc/hermes-env`.

**No per-task exec model** — this VM boots once, secrets get pushed, the service starts, and it just runs. `tools/incus/hermes-vm-manage.sh` is for lifecycle ops (start/stop/status/logs), not job dispatch.

### 2.3 Secrets landing in the guest

Same host→guest push pattern as `byok-agent`:

```bash
incus file push /run/agenix/hermes-agent-secrets \
  "${VM_NAME}/etc/hermes-env" -p 0600 --uid 0 --gid 0
```

`hermes-agent.service` loads it via `EnvironmentFile`. Push happens on VM boot (host script, or a `pre-start` hook) — not baked into the image.

---

## **Step 3: Installing Hermes Agent in the guest**

### 3.1 Install

```bash
# Official installer — verify current URL/flags against
# hermes-agent.nousresearch.com/docs at implement time
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

### 3.2 Provider config

Hermes reads model/provider config from its own config file plus env. Map secrets:

- `OPENROUTER_API_KEY` → Hermes's OpenRouter provider slot (set as default provider for v1 — broadest model coverage per BYOK key)
- `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` → optional additional provider slots if you want to route specific tasks to a specific model family later

Run `hermes setup` once interactively on first boot to generate the base config, then let subsequent boots just start the service against the existing `~/.hermes/` config — don't re-run the wizard on every boot.

### 3.3 Telegram channel

```bash
hermes telegram configure --token "$TELEGRAM_BOT_TOKEN" --allowed-users "$TELEGRAM_ALLOWED_USERS"
```

(Confirm exact subcommand in current docs — channel setup commands have moved around between Hermes versions.) This is the channel *you* talk to Hermes through day-to-day — separate from the ops notify script.

### 3.4 Skills relevant to your workflow

Since one of your original complaints was "add skills" being painful in OpenClaw — Hermes writes skills automatically as it solves tasks, but you can also seed it:

- A skill (or plain instruction in its workspace file) covering your repo conventions (git identity via `includeIf`, agenix secret flow, `manage-secret` usage) so it doesn't need to relearn your NixOS setup's quirks from scratch on early tasks.
- Point its default working directory at a scratch clone location, not directly at `~/config` with secrets in scope — same principle as the coding-agent VM.

---

## **Step 4: Host management script (`tools/incus/hermes-vm-manage.sh`)**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   hermes-vm-manage.sh start|stop|status|logs|push-secrets

VM_NAME="${VM_NAME:-hermes-agent}"
PROFILE="${PROFILE:-hermes-agent}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/hermes-agent-secrets}"

# start:        incus start "$VM_NAME" if stopped; wait for cloud-init on
#               first boot; push-secrets; incus exec -- systemctl start hermes-agent
# stop:         incus exec -- systemctl stop hermes-agent; incus stop "$VM_NAME"
# status:       incus exec -- systemctl status hermes-agent
# logs:         incus exec -- journalctl -u hermes-agent -f
# push-secrets: incus file push "$SECRETS_PATH" "${VM_NAME}/etc/hermes-env" -p 0600 --uid 0 --gid 0
```

No task-dispatch subcommand — Hermes handles its own task queue internally once you're messaging it via Telegram.

---

## **Step 5: Backups (replaces golden-snapshot/reset for this VM)**

`~/.hermes/` is the one thing you can't regenerate — back it up like the other stateful services on `home-server` (Audiobookshelf, etc.), same restic+rclone+R2 pattern.

`tools/incus/hermes-backup.sh` (called by the host systemd timer from Step 2.1):

```bash
#!/usr/bin/env bash
set -euo pipefail
source /run/agenix/hermes-agent-secrets   # RESTIC_REPOSITORY / RESTIC_PASSWORD
VM_NAME="${VM_NAME:-hermes-agent}"

TMP=$(mktemp -d)
incus file pull -r "${VM_NAME}/root/.hermes" "$TMP"
restic backup "$TMP/.hermes" --tag hermes-agent
restic forget --keep-daily 7 --keep-weekly 4 --prune
rm -rf "$TMP"
```

| Asset | Location | Survives reboot? | Backed up? |
| --- | --- | --- | --- |
| OS + Hermes install | VM root disk | Yes | No (reinstallable via cloud-init + Step 3.1) |
| Memory DB, skills, config | `~/.hermes/` | Yes | Yes — daily restic → R2 |
| Injected secrets | `/etc/hermes-env` | Until overwritten | No (re-pushed from agenix on every start) |

**Recovery from a broken guest:** rebuild the VM from the profile (fresh cloud-init), reinstall Hermes (Step 3.1), then `incus file push` the latest restic snapshot's `.hermes/` back into `~/.hermes` before starting the service. This is closer to a normal service restore than the coding-agent VM's snapshot-restore — appropriate since the thing you're protecting is accumulated memory, not a golden toolchain image.

---

## **Step 6: Bridging to `byok-agent` (Hermes triggers coding tasks)**

Hermes and `byok-agent` stay on **separate VMs** (see rationale above) but need to interact: Hermes should be able to hand off "clone this repo and fix X" to OpenHands/OpenCode running on `byok-agent`, and get notified when it's done. This is the same shape as a chat bot triggering a background coding agent — the bridge lives on the **host**, not inside either VM, so neither VM ever holds the other's credentials.

### 6.1 Host-side MCP bridge (`tools/incus/coding-task-bridge/`)

A small, single-purpose MCP server running on `home-server` itself (outside Incus), exposing one tool:

```
trigger_coding_task(repo: str, prompt: str, model?: str) -> { job_id: str }
```

Internally it just shells out to the existing `tools/incus/run-agent-task.sh` from the `byok-agent` plan — no new task-dispatch logic, this is purely a network-reachable wrapper around a script that already works.

Requirements:

- **Bind only to the Incus bridge address** (`incusbr0`), not `0.0.0.0` — reachable from guest VMs, not from LAN/WAN.
- **Shared-secret auth** — a bearer token in a new `hermes-bridge-secrets.age` entry, checked on every call. Store it once, inject into both: Hermes's MCP client config (guest) and the bridge server's expected-token config (host).
- **Fire-and-forget** — the tool call returns a `job_id` immediately (`run-agent-task.sh` backgrounds the actual `incus exec` and returns); it does **not** block waiting for the coding task to finish. Multi-minute OpenHands runs must not hang Hermes's response loop.
- **No repo/credential access on the host process itself** beyond invoking the script — the bridge process should run as an unprivileged service user, not root, and should not read `/run/agenix/incus-ai-agent-secrets` directly (only `run-agent-task.sh`, invoked as the privileged user via a narrowly-scoped sudo rule, needs that).

### 6.2 Registering the bridge with Hermes

Hermes speaks MCP natively over HTTP, so from the guest side this is just config, not code:

```bash
hermes mcp add coding-bridge --url http://<incusbr0-host-ip>:<port>/mcp --token "$BRIDGE_TOKEN"
```

(Confirm exact `hermes mcp add` flags against current docs at implement time.) Once registered, Hermes can decide on its own — same as any other tool — to call `trigger_coding_task` when you ask it to fix something in a repo, instead of trying to do the coding work itself via its own terminal tool.

### 6.3 Completion notification loop

`guest-run-agent-task.sh` on `byok-agent` (from the coding-agent plan) already sends a Telegram start/finish/fail message. Point that at a channel Hermes also monitors:

- Simplest: same bot/chat as Hermes's own Telegram channel, with a fixed prefix (e.g. `[byok-agent]`) so it's visually distinguishable from Hermes's own messages.
- Hermes then sees the completion message land in its conversation like anything else and can summarize/relay it back to you, or react to it (e.g. trigger a follow-up) if you want that later — no special-casing required on Hermes's side for v1.

### 6.4 Secrets addendum

Add to `nix/secrets/secrets.nix`:

```nix
"hermes-bridge-secrets.age" = rootConfig;
```

```env
BRIDGE_TOKEN="..."          # shared secret, host bridge <-> Hermes MCP client
BRIDGE_BIND_ADDR="<incusbr0 host ip>"
BRIDGE_PORT="8420"
```

Push `BRIDGE_TOKEN` into both the bridge service's env (host, from `/run/agenix/hermes-bridge-secrets`) and Hermes's guest env (`/etc/hermes-env`, alongside the other Hermes secrets) so both sides authenticate the same value without it ever touching `byok-agent`.

### 6.5 What this deliberately does *not* do (v1)

- No synchronous "wait for the fix, then reply" flow — keeps Hermes responsive and avoids timeout handling for long-running tasks.
- No shared filesystem between the VMs — `byok-agent` clones its own copy; Hermes never needs read access to `byok-agent`'s workspace.
- No reverse direction (OpenHands triggering Hermes) — out of scope until there's an actual use case for it.

---

## **Step 7: Security notes**

- **Two separate Telegram bots**, as in Step 1 — don't let Hermes's channel token double as your ops-alert token.
- **Keys only on host→guest secret path** — same agenix → `/run/agenix/` → `incus file push` flow as `byok-agent`. Never in the Incus profile, cloud-init, git, or chat messages.
- **No secrets in Hermes memory** — if you ever paste a token into a Telegram message to Hermes "just to test something," assume it's now in its persistent memory DB and in your R2 backups. Don't.
- **Browser automation = broader attack surface than the coding VM.** Hermes browsing arbitrary social-media pages on your behalf means it's fetching untrusted content routinely, not just per-task. Keep this VM's GitHub PAT scoped tighter than you might otherwise (read + PR-only on specific repos, not full account access), since this is the VM most exposed to prompt-injection-via-webpage.
- **Least privilege on channels** — `TELEGRAM_ALLOWED_USERS` restricted to your own user ID only; don't open the bot to a group chat.
- **Outbound only in v1** — Telegram long-polling needs no inbound port; don't expose a webhook port on LAN/WAN unless you specifically move to a webhook-based channel later.

---

## **Implementation order**

1. Add `secrets.nix` entry; create `hermes-agent-secrets.age` via `manage-secret` (two Telegram bot tokens, OpenRouter key, GitHub PAT, restic repo/password).
2. Add `modules/incus-hermes-agent/default.nix` (profile + enable option + backup timer skeleton).
3. Import from `home-server/default.nix`; leave `enable = false` until ready.
4. Add `tools/incus/hermes-vm-manage.sh` and `tools/incus/hermes-backup.sh`.
5. `nixos-rebuild switch` on home-server; launch VM once; wait for cloud-init.
6. Run `hermes setup` interactively once inside the guest; configure Telegram channel (Step 3.3).
7. Enable and start `hermes-agent.service`; confirm you can message it via Telegram.
8. Run one real end-to-end task through Hermes (something low-stakes) to confirm skills/memory get written.
9. Flip on the backup timer; manually trigger `hermes-backup.sh` once and confirm the R2 snapshot exists.
10. Build the host bridge (Step 6): `hermes-bridge-secrets.age`, the MCP server itself, register it with `hermes mcp add`, point `byok-agent`'s completion notify at a channel Hermes monitors.
11. End-to-end bridge test: ask Hermes (via Telegram) to fix something trivial in a scratch repo, confirm it calls `trigger_coding_task` rather than trying to do it itself, confirm the `byok-agent` completion message shows up.
12. Update the tracking issue's checklist.

---

## **Verification checklist**

1. **Decrypt check:** `sudo cat /run/agenix/hermes-agent-secrets` shows expected keys; no plaintext in git.
2. **Module off/on:** `enable = false` → no `hermes-agent` profile present; `enable = true` → profile renders cleanly.
3. **First boot:** VM launches, cloud-init completes, Hermes installs without manual intervention beyond `hermes setup`.
4. **Channel test:** message the Telegram bot, get a response, confirm `TELEGRAM_ALLOWED_USERS` actually blocks other user IDs (test from a second account if possible).
5. **Persistence test:** stop/start the VM (not delete) — confirm memory/skills from before the restart are still referenced in a follow-up message.
6. **Backup test:** `hermes-backup.sh` runs clean; `restic snapshots` shows the new entry; spot-check a restored file matches.
7. **Security spot-check:** `incus config show hermes-agent` / cloud-init user-data contain no API keys or tokens.
8. **Isolation check:** confirm `hermes-agent` and `byok-agent` are genuinely separate VMs with separate credentials — no shared secret file, no shared GitHub PAT.
9. **Bridge reachability:** the MCP bridge port answers from inside `hermes-agent` but is unreachable from LAN/WAN (test with `curl` from outside `incusbr0`).
10. **Bridge auth:** a request with a wrong/missing `BRIDGE_TOKEN` is rejected.
11. **Bridge non-blocking:** `trigger_coding_task` returns a `job_id` immediately, well before the underlying OpenHands/OpenCode run finishes.
12. **Bridge end-to-end:** Hermes calls the tool for a real (trivial) task, `byok-agent` runs it, and the completion Telegram message is visible to Hermes's channel.

---

## **Proposed tracking issue**

**Title:** Persistent Hermes Agent Incus VM (messaging + memory + skills)

**Body sketch:**

```markdown
Companion to #31 — a separate always-on Incus VM running Hermes Agent
(BYOK personal-agent runtime: memory, skills, Telegram channel, reminders,
browser automation) rather than the task-triggered coding-agent VM.

Plan: `misc/plans/incus-hermes-agent/hermes-agent.md`

- [ ] Secrets + module skeleton
- [ ] First boot + `hermes setup` + Telegram channel live
- [ ] Backup timer verified against R2
- [ ] Real end-to-end task run through Hermes
```
