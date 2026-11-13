# Hand-off: harness-agnostic rule + create-skill (enesbala5/config)

Work in a local checkout of `enesbala5/config`. `git fetch`, branch from current `main` (was `769f14a` on 2026-11-11). Branch name: `harness-agnostic-rule` (no prefix). Sign commits with Enes's key. No `Co-authored-by` trailers. Open ONE PR into `main`; do not merge; do not change repo settings.

Context found in the repo:
- `misc/agents/AGENTS.md`: harness-neutral always-on instructions (currently only points at `i-have-adhd`). Symlinked to `~/.pi/agent/AGENTS.md`.
- `misc/rules/general/*.mdc`: always-apply rules (frontmatter `description`, `alwaysApply: true`). Symlinked as `~/.cursor/rules`.
- `misc/skills/`: 102 global skills. Live-symlinked as `~/.agents/skills` on Framework 13 via `mkOutOfStoreSymlink` in `nix/nixos/hosts/framework-13/home/default.nix`.
- No create-skill / skill-creator exists (closest: `misc/skills/find-skills`), so it must be CREATED.
- OpenHands Incus VM gets copies via `tools/incus/agent-vm-manage.sh` (not a live symlink). home-server has no symlinks.

## 1. NEW `misc/rules/general/harness-agnostic.mdc`

~~~~
---
description: Skills, rules, and playbooks must work in any coding-agent harness
alwaysApply: true
---

## Harness-agnostic agent tooling
- Anything for AI agents (skills, rules, playbooks, prompts, scripts) must work in any coding-agent harness: Cursor, Claude Code, Codex, Pi, OpenHands, Hermes, etc. No harness-specific fixes or features.
- Use open, widely supported conventions: AGENTS.md as the entry point, skills as plain folders with a SKILL.md (name + description frontmatter, plain-markdown body), and plain shell/Make/HTTP commands any agent can run.
- Store shared skills in a neutral location (.agents/skills/), not a harness folder like .cursor/ or .claude/. If a harness needs its own path, make it a symlink or a one-line pointer to the neutral copy, never a second copy.
- Skills must be self-contained: no reliance on a specific harness's tools, MCP servers, or slash commands. If a step needs an external service, document how to reach it (URL, env var, command).
- Anything non-obvious (custom conventions, required env vars, start-up steps, paths, gotchas) must be documented in AGENTS.md (or the nearest folder-level AGENTS.md) so any agent can discover it without prior context.
~~~~

## 2. EDIT `misc/agents/AGENTS.md` (replace whole file)

~~~~
# Default agent instructions

Always apply the `i-have-adhd` skill (`~/.agents/skills/i-have-adhd/SKILL.md`)
in every response. The skill is the spec; this file only points at it. Stays on
until the user says "stop adhd mode" or "normal mode".

Always follow the harness-agnostic agent tooling rule
(`misc/rules/general/harness-agnostic.mdc`; also
https://github.com/enesbala5/config/blob/main/misc/rules/general/harness-agnostic.mdc).
Read that file and apply it whenever creating or editing skills, rules,
playbooks, or prompts.
~~~~

## 3. NEW `misc/skills/create-skill/SKILL.md`

~~~~
---
name: create-skill
description: Create a new agent skill as a SKILL.md folder. Use when the user wants to add, write, or scaffold a skill, or says "create a skill", "new skill", or "save this as a skill". Works in any coding-agent harness.
---

# Create a skill

Follow the harness-agnostic agent tooling rule before writing anything:

- Repo path: `misc/rules/general/harness-agnostic.mdc`
- GitHub: https://github.com/enesbala5/config/blob/main/misc/rules/general/harness-agnostic.mdc
- On Enes's Nix machines it also appears at `~/.cursor/rules/general/harness-agnostic.mdc`.

Read that file and apply it. No harness-specific fixes, MCP-only steps, or a second copy of a skill in `.cursor/skills` or `.claude/skills`.

## Step 1: Ask global or project-scoped

Before choosing a path or writing files, ask whether the skill is:

- GLOBAL: reusable across projects, stored in the `enesbala5/config` repo
- PROJECT-SCOPED: tied to one repository or project

Do not default. Wait for the answer.

## Step 2: Write the skill

A skill is a folder with a `SKILL.md`:

```yaml
---
name: skill-name
description: What it does and when to use it, specific enough that an agent can decide to load it.
---
```

Then a plain-markdown body. Keep it self-contained: open conventions (`AGENTS.md`, `SKILL.md`, plain shell / Make / HTTP). If a step needs an external service, document the URL, env var, or command. Put non-obvious conventions, env vars, startup steps, and gotchas in the nearest `AGENTS.md`.

### Project-scoped

Write only to `<project>/.agents/skills/<name>/SKILL.md`.

If a harness only reads its own folder (`.cursor/skills`, `.claude/skills`, ...), add a symlink or one-line pointer to the `.agents/skills/<name>` copy, never a second copy. If anything is non-obvious, mention the skill in the project's `AGENTS.md`.

### Global

Write to `misc/skills/<name>/SKILL.md` in `enesbala5/config` (https://github.com/enesbala5/config).

On Enes's Nix machines (Framework 13), home-manager live-symlinks that directory (`nix/nixos/hosts/framework-13/home/default.nix`):

```nix
".agents/skills" = {
  source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/misc/skills";
  recursive = true;
};
```

`data.configDirectory` is the config checkout, usually `~/config`, so editing `~/config/misc/skills/<name>/` is immediately visible at `~/.agents/skills/<name>/`. Cursor rules are a separate symlink (`~/.cursor/rules` -> `misc/rules`); do not put skills there. On those machines: edit the local config checkout, then commit and push (or open a PR).

On cloud or remote environments without that symlink (cloud agents, devcontainers, CI, the OpenHands Incus VM, other machines): never save the skill only locally. Always propose opening a PR to `enesbala5/config` adding `misc/skills/<name>/SKILL.md`. The OpenHands VM only gets a copy when `tools/incus/agent-vm-manage.sh` pushes it.

## Step 3: Check

- Works in any harness; no Cursor/Claude/Pi-only commands or MCP tool names as hard requirements.
- One canonical copy.
- Frontmatter `name` matches the folder name.
- Description says what it does and when to use it.
~~~~

## Commits and PR

- Commit 1: `Add harness-agnostic agent tooling rule` (files 1, 2)
- Commit 2: `Add create-skill skill that asks global vs project scope` (file 3)
- PR title: `Add harness-agnostic agent rule; create-skill asks global vs project scope`
- PR body: list the three changes; note create-skill is new (none existed).
- Optional: one line in `tools/pi/README.md` noting AGENTS.md now points at this rule. Do NOT move `misc/skills` or `tools/hermes-skills/`.

After merge: Framework 13 picks up file contents immediately. Pi needs `/reload`. OpenHands VM needs `agent-vm-manage.sh push-rules` and `push-skills`.
