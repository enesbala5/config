# Implementation Plan: Persistent BYOK Incus Agent VM (Chat-Delegated)

> **Supersedes (directionally):** [`initial.md`](./initial.md) (Cursor Self-Hosted Worker). Keep `initial.md` as the historical Cursor-oriented plan. This document is the primary implementation path going forward.
>
> **Tracks:** [GitHub issue #31](https://github.com/enesbala5/config/issues/31) — originally titled “Add Incus VM Instance for self-hosted Cursor Agent”; update the issue title/body after this plan lands (proposed text at the end).

## **Objective**

Run a **persistent, warm** Incus VM on `home-server` that hosts a **BYOK coding-agent harness** (OpenHands and/or OpenCode — not Cursor `agent worker` as the primary design). Tasks are triggered from a thin host interface that a chat coordinator (e.g. Grok Bot) can call later: “open a task from chat → run on the home-server Incus VM.”

LLM usage is billed to **DeepSeek** (and optional Grok/xAI / OpenRouter) API keys stored in age secrets — not the Cursor credit pool. Useful pieces from `initial.md` are retained: Telegram notify via host `tools/telegram/notify.sh`, GitHub token for clone/PR work, Incus profile/limits, and host→guest secrets injection.

The whole feature is a **toggleable, host-scoped NixOS module** under `nix/nixos/hosts/home-server/modules/` so other hosts are unaffected and home-server can disable it without deleting the module.

**Out of scope for the first implementation PR (this plan’s apply phase):** building a full chat platform, Cursor worker as primary path, or multi-tenant agent fleets. Chat glue in v1 is a documented host script + interface contract only.

---

## **Product pivot (why this plan)**

| | Old (`initial.md`) | New (this plan) |
| --- | --- | --- |
| Role of VM | Cursor Self-Hosted Machine (`agent worker start`) | Persistent BYOK coding-agent environment |
| Cost model | Cursor credits / `CURSOR_API_KEY` | DeepSeek (+ optional xAI/OpenRouter) BYOK |
| Lifecycle | Spawn/launch per worker script | Long-lived warm VM; deps/clones/caches survive |
| Trigger | Manual `spawn-cursor-worker.sh` | Host `run-agent-task.sh` callable by chat coordinator later |
| Isolation | Incus profile + secrets push | Same, plus module enable flag + golden snapshot restore |

Cursor already includes managed compute, so a Cursor worker VM is not the cost win. Keep Cursor worker as an **optional appendix** only.

---

## **File Structure & Deliverables**

```
nix/nixos/hosts/home-server/
├── default.nix                          # import ./modules/incus-ai-agent (gated by enable)
└── modules/incus-ai-agent/
    └── default.nix                      # toggleable module: profile, age secret wire-up, helpers

nix/secrets/
├── secrets.nix                          # register incus-ai-agent-secrets.age
└── incus-ai-agent-secrets.age           # user-encrypted env (manual manage-secret)

tools/incus/
├── run-agent-task.sh                    # host entrypoint: ensure VM up, push secrets, incus exec job
└── reset-agent-vm.sh                    # optional: restore from golden snapshot

# Inside guest (via cloud-init / profile user-data — not separate repo files):
#   /usr/local/bin/notify.sh
#   /usr/local/bin/guest-run-agent-task.sh
#   /var/lib/ai-agent/                   # warm workspace (clones, caches)
```

**Naming (chosen for this repo):**

| Concept | Name |
| --- | --- |
| Module dir | `modules/incus-ai-agent/` |
| Module option | `homeServer.incusAiAgent.enable` |
| Incus profile | `byok-agent` |
| Persistent VM name | `byok-agent` (single warm instance for v1) |
| Age secret file | `incus-ai-agent-secrets.age` → `/run/agenix/incus-ai-agent-secrets` |
| Host scripts | `tools/incus/run-agent-task.sh`, `tools/incus/reset-agent-vm.sh` |

Do **not** use Cursor-only names (`cursor-worker`, `spawn-cursor-worker.sh`, `CURSOR_API_KEY` as required) in the primary path.

---

## **Step 1: Secrets Schema (`nix/secrets/incus-ai-agent-secrets.age`)**

Create and encrypt via the existing flow (same as other secrets):

```bash
manage-secret incus-ai-agent-secrets.age
```

Paste env content shaped like:

```env
# Required for v1 — DeepSeek BYOK
DEEPSEEK_API_KEY="sk-..."

# Optional providers (omit or leave empty if unused)
XAI_API_KEY=""
# Alias some stacks expect:
# GROK_API_KEY=""
OPENROUTER_API_KEY=""

# Git (fine-grained PAT: contents + PRs on target repos)
GITHUB_TOKEN="ghp_..."

# Telegram (may reuse host default-telegram values, or dedicated chat)
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHI..."
TELEGRAM_CHAT_ID="987654321"

# Agent defaults
WORKSPACE_DIR="/var/lib/ai-agent/workspace"
DEFAULT_MODEL="deepseek/deepseek-chat"
# Optional escalation model id for later routing
ESCALATE_MODEL="deepseek/deepseek-reasoner"
```

Register in `nix/secrets/secrets.nix` with `rootConfig` (host pushes into guest as root):

```nix
"incus-ai-agent-secrets.age" = rootConfig;
```

`base-configuration.nix` already maps every `secrets.nix` entry into `age.secrets.<nameWithoutAge>`, so no special agenix wiring beyond the secrets.nix entry + the `.age` file existing.

> Do not commit decrypted credentials. Placeholders above are documentation only.

---

## **Step 2: Toggleable NixOS Module (`modules/incus-ai-agent/default.nix`)**

### 2.1 Import + enable gate

In `nix/nixos/hosts/home-server/default.nix`:

```nix
imports = [
  # ...existing...
  ./modules/incus-ai-agent
];
```

Module skeleton (host-scoped, like garage/backups/power):

```nix
{ config, lib, pkgs, data, ... }:

let
  cfg = config.homeServer.incusAiAgent;
  telegramScriptContent = builtins.readFile "${data.configDirectory}/tools/telegram/notify.sh";
in
{
  options.homeServer.incusAiAgent = {
    enable = lib.mkEnableOption "persistent BYOK Incus AI agent VM (profile + host helpers)";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "byok-agent";
      description = "Persistent Incus VM instance name";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "byok-agent";
      description = "Incus profile name providing cloud-init + limits";
    };

    limits = {
      cpu = lib.mkOption { type = lib.types.str; default = "4"; };
      memory = lib.mkOption { type = lib.types.str; default = "8GiB"; };
    };
  };

  config = lib.mkIf cfg.enable {
    # Merge byok-agent profile into virtualisation.incus.preseed.profiles
    # (append alongside existing default profile — do not replace default).
    #
    # Also ensure the interactive/admin user can run incus (already on
    # incus-admin for root; add data.username to incus-admin if missing).
  };
}
```

When `enable = false`, the module contributes **nothing** (no profile, no side effects). Default can be `false` until secrets + first apply are ready; flip to `true` in `home-server/default.nix` or via `homeServer.incusAiAgent.enable = true`.

### 2.2 Incus profile — persistent warm VM (not spawn-from-scratch)

Profile goals:

- CPU/memory limits (defaults above; nesting on if Docker-in-guest is used for OpenHands runtime).
- `user.user-data` cloud-init that installs base packages once and writes guest helper scripts.
- **Disk:** use the instance root disk (from `default` profile / launch) sized for warm caches — prefer ≥35GiB already used by home-server default profile, or attach an extra disk/device later if workspace should live on HDD. Document choice in module comments; v1 can keep workspace on the VM root under `/var/lib/ai-agent`.

Cloud-init packages (minimum):

- `git`, `curl`, `jq`, `ca-certificates`, `build-essential` (or `gcc`/`g++`/`make` on the guest distro)
- `docker.io` **if** OpenHands is installed via Docker runtime (security.nesting = true)
- Node / Python only as required by the chosen harness install path (prefer official install scripts in `runcmd`, not baking every toolchain into packages unless needed)

Injected files via cloud-init `write_files`:

1. `/usr/local/bin/notify.sh` — content from host `tools/telegram/notify.sh` (same pattern as `initial.md`).
2. `/usr/local/bin/guest-run-agent-task.sh` — loads `/etc/agent-env`, configures git HTTPS with `GITHUB_TOKEN`, Telegram start/finish/fail, invokes harness (see Step 4).
3. Ensure `/var/lib/ai-agent/{workspace,cache,logs}` exist (`runcmd` mkdir + permissions).

**Persistence model:** the VM instance `byok-agent` is created once and left running (or stopped but disk retained). Host script starts it if needed; it does **not** `incus delete` between tasks. Clones under `/var/lib/ai-agent/workspace` and package caches survive.

### 2.3 Secrets landing in the guest

Do **not** bake API keys into cloud-init or the Incus profile.

At task start (and optionally on a small systemd timer / boot hook later), host pushes:

```bash
incus file push /run/agenix/incus-ai-agent-secrets \
  "${VM_NAME}/etc/agent-env" -p 0600 --uid 0 --gid 0
```

Guest scripts `source` `/etc/agent-env` with `set -o allexport`. Never echo secret values into Telegram or chat logs.

---

## **Step 3: Agent harness on the VM (OpenHands and/or OpenCode)**

### 3.1 Recommendation (v1)

**Primary:** [OpenCode](https://opencode.ai) — lightweight CLI, good BYOK fit, headless `opencode run`.

**Alternative / parallel:** [OpenHands](https://github.com/OpenHands/OpenHands) CLI — `openhands --headless -t "..."`; heavier if using Docker runtime.

Implementers may install **one** for v1 (prefer OpenCode if choosing a single harness) and leave a module option `harness = "opencode" | "openhands"` for later.

### 3.2 Model routing

- **Default:** DeepSeek Flash / chat-tier model (`DEFAULT_MODEL`, e.g. `deepseek/deepseek-chat` or current Flash id — pin a concrete id at implement time against provider docs).
- **Escalate later:** `ESCALATE_MODEL` or a `--model` flag on the host script; v1 can pass through `MODEL` env without auto-routing logic.
- Map `DEEPSEEK_API_KEY` into whatever env the harness expects (`DEEPSEEK_API_KEY`, and/or `LLM_API_KEY` + `LLM_MODEL` + `LLM_BASE_URL=https://api.deepseek.com` for OpenHands).

### 3.3 Install (cloud-init `runcmd` or first-boot script)

Sketch (adjust to current upstream install docs when implementing):

```bash
# OpenCode (example — verify URL/flags at apply time)
curl -fsSL https://opencode.ai/install | bash

# OR OpenHands CLI (example)
# pipx / uv / official install — prefer non-interactive
# Ensure docker available if runtime=docker
```

Pin versions where practical; re-run install only on golden rebuild, not every task.

### 3.4 Headless job invocation (guest)

`guest-run-agent-task.sh` contract:

```bash
# Args (v1):
#   --repo URL          optional; clone or update under WORKSPACE_DIR/<name>
#   --prompt TEXT       required task text
#   --model ID          optional override
#   --workdir PATH      optional existing directory

# Pseudocode:
source /etc/agent-env
notify start (no secrets in message)
prepare git auth from GITHUB_TOKEN
cd workspace; clone/update repo if --repo
export harness env from DEEPSEEK_API_KEY / DEFAULT_MODEL
opencode run -m "$MODEL" --dangerously-skip-permissions "$PROMPT"
# OR: openhands --headless --override-with-envs -t "$PROMPT"
notify success/failure with exit code + short summary (repo name, model id — never keys)
```

Log harness stdout/stderr to `/var/lib/ai-agent/logs/<timestamp>.log` (mode 0600). Do not ship full logs to Telegram by default (size + accidental secret leakage); Telegram gets status only. Optional later: truncated tail.

---

## **Step 4: Host trigger / chat coordinator glue (thin v1)**

### 4.1 Host script `tools/incus/run-agent-task.sh`

This is the **stable interface** chat bots and humans call.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   run-agent-task.sh --prompt "Fix flaky test in auth" [--repo https://github.com/org/repo.git] [--model ...]
#   run-agent-task.sh --prompt-file ./task.md [--repo ...]

VM_NAME="${VM_NAME:-byok-agent}"
PROFILE="${PROFILE:-byok-agent}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/incus-ai-agent-secrets}"

# 1. Require secrets file on host
# 2. Ensure VM exists: if missing, incus launch images:ubuntu/24.04 "$VM_NAME" --profile default --profile "$PROFILE" --vm
# 3. incus start if stopped
# 4. Wait for agent: incus exec ... -- cloud-init status --wait (first boot only; subsequent starts: wait for ping/exec)
# 5. Push secrets to /etc/agent-env
# 6. incus exec "$VM_NAME" -- /usr/local/bin/guest-run-agent-task.sh "$@"
```

Make executable; optionally wrap with a zsh alias later (not required for v1).

### 4.2 Chat coordinator contract (document only — do not build the bot in v1)

Grok Bot / webhook / Telegram command handler should eventually:

1. Authenticate the requesting user (out of scope here).
2. Parse `{repo?, prompt, model?}`.
3. Invoke on home-server (SSH, local systemd, or queue):

   ```bash
   /path/to/config/tools/incus/run-agent-task.sh \
     --repo "$REPO" \
     --prompt "$PROMPT"
   ```

4. Relay Telegram notifications already emitted by the guest, **or** capture exit code and post a single summary — avoid duplicating secret-bearing output.

v1 success = human can run the host script; bot integration is a follow-up issue.

---

## **Step 5: Persistence, golden snapshot, recovery**

| Asset | Location | Survives reboot? | Survives `incus delete`? |
| --- | --- | --- | --- |
| OS + harness install | VM root disk | Yes | No |
| Repo clones / worktrees | `/var/lib/ai-agent/workspace` | Yes | No |
| Caches | `/var/lib/ai-agent/cache` | Yes | No |
| Injected secrets | `/etc/agent-env` | Until overwritten; re-push each task | No |

**Golden snapshot workflow** (document in script comments + this plan):

1. After first successful provision + harness smoke test, create:

   ```bash
   incus snapshot create byok-agent golden
   ```

2. `tools/incus/reset-agent-vm.sh`:

   ```bash
   incus stop byok-agent || true
   incus snapshot restore byok-agent golden
   incus start byok-agent
   # re-push secrets before next task
   ```

3. Guidance: restore when the agent trashes the toolchain, fills disk with junk, or leaves the guest in a bad state. Prefer restoring golden over ad-hoc repair for v1.

Optional later: publish workspace to a host bind-mount on `/mnt/hdd/...` so restores do not wipe in-progress clones — not required for v1.

---

## **Step 6: Security notes**

- **Keys only on host→guest secret path:** age decrypt on host (`/run/agenix/...`); push to guest `/etc/agent-env` mode `0600`. Never put keys in Incus profile, git, chat prompts, or Telegram messages.
- **No secrets in chat logs:** notify messages may include VM name, repo URL, model id, exit code — never env dumps or API key substrings.
- **Outbound HTTPS:** guest needs egress to DeepSeek / optional xAI / GitHub / Telegram. Incus `incusbr0` already NATs; do not expose agent SSH/API ports to LAN/WAN in v1 unless explicitly required.
- **Least privilege:** fine-grained GitHub PAT scoped to needed repos; Telegram bot limited to the ops chat; module enable flag off by default until ready; single VM, not a public multi-tenant runner.
- **Nesting/Docker:** only enable if the chosen harness needs it; treat Docker socket access as high privilege inside the guest.
- **Host trust boundary:** anyone who can `incus exec` or read `/run/agenix/incus-ai-agent-secrets` can use the keys — keep `incus-admin` and agenix paths restricted.

---

## **Step 7: Migration note from `initial.md`**

| Keep from old plan | Drop / demote |
| --- | --- |
| Telegram via `tools/telegram/notify.sh` | `CURSOR_API_KEY` as primary |
| GitHub token + git insteadOf HTTPS | `agent worker start` as primary entrypoint |
| Incus profile + limits + cloud-init inject | Ephemeral “spawn worker” mental model |
| Host push of decrypted age secrets | Naming: `cursor-worker`, `spawn-cursor-worker.sh` |
| `manage-secret` manual encrypt flow | |

**Optional appendix (future, not v1):** a second profile or script path that installs Cursor CLI and runs `agent worker start` for Cursor self-hosted experiments. If added, gate behind `homeServer.incusAiAgent.cursorWorker.enable` and keep BYOK harness as default. Do not block the primary path on Cursor worker support.

---

## **Implementation order (for the apply PR)**

1. Add secrets.nix entry; user creates `incus-ai-agent-secrets.age` with `manage-secret`.
2. Add `modules/incus-ai-agent/default.nix` with enable option + Incus profile cloud-init.
3. Import module from `home-server/default.nix`; set `homeServer.incusAiAgent.enable = true` when ready.
4. Add `tools/incus/run-agent-task.sh` (+ optional `reset-agent-vm.sh`).
5. `nixos-rebuild switch` on home-server; launch VM once; wait for cloud-init.
6. Smoke-test harness with a tiny prompt (no private repos first).
7. `incus snapshot create byok-agent golden`.
8. Run a real `--repo` + `--prompt` task; confirm Telegram start/finish.
9. Update issue #31 checklist (“Apply changes”) when done.

---

## **Execution Verification Checklist**

> 1. **Decrypt check:** `sudo cat /run/agenix/incus-ai-agent-secrets` on home-server shows expected keys (mode 0400/0600); no plaintext in git.
> 2. **Module off/on:** With `homeServer.incusAiAgent.enable = false`, `incus profile show byok-agent` is absent/unchanged by module; with `true`, profile exists and `user.user-data` renders without Nix interpolation errors.
> 3. **Profile check:** `incus profile show byok-agent` includes limits, nesting (if needed), and cloud-init packages/scripts.
> 4. **First boot:** `tools/incus/run-agent-task.sh --prompt "Respond with: pong"` creates/starts VM, pushes secrets, harness runs, exit 0.
> 5. **Warm persistence:** Second run does not reinstall the harness from scratch; a prior clone under `/var/lib/ai-agent/workspace` still exists (`incus exec byok-agent -- ls ...`).
> 6. **Telegram:** Start + success/failure messages arrive; messages contain no API keys.
> 7. **GitHub (optional in smoke):** `--repo` clone works with `GITHUB_TOKEN`; push/PR only if PAT scoped and explicitly tested.
> 8. **Reset:** After intentional guest breakage, `reset-agent-vm.sh` (or manual snapshot restore) returns to golden; re-push secrets; task runs again.
> 9. **Security spot-check:** `incus config show byok-agent` / profile user-data do not embed `DEEPSEEK_API_KEY` or tokens.

---

## **Proposed issue #31 update (manual)**

**Title:** Persistent BYOK Incus AI agent VM (chat-delegable)

**Body sketch:**

```markdown
Pivot from Cursor self-hosted worker to a persistent BYOK agent VM on home-server Incus.

Plan: `misc/plans/incus-ai-agent/byok-chat-delegation.md` (historical Cursor plan: `initial.md`).

- [x] Prepare plan
- [ ] Apply NixOS module + host scripts
- [ ] Encrypt secrets + smoke test + golden snapshot
- [ ] (Later) Wire Grok Bot / chat coordinator to `tools/incus/run-agent-task.sh`
```

Leave a short comment on #31 pointing at the plan PR once merged or when starting apply work.
