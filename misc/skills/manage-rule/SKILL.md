---
name: manage-rule
description: Create, update, list, or remove persistent agent rules using AGENTS.md as the harness-neutral entry point. Use for /manage-rule, "add an agent rule", or requests for always-on instructions, including discovery of repository-local skills.
---

# Manage rules

Treat `/manage-rule` as a request for this workflow, not a required command.
Follow these instructions with ordinary file and shell operations in any harness.

## 1. Inspect scope and existing instructions

Read the target repository's `AGENTS.md`, relevant folder-level instructions,
existing rule files, and `git status --short`. Preserve unrelated edits.
Honor an explicit local/repository or global scope. If scope is unspecified,
ask "Global, or local to this repository?" and wait before writing files.
For changes requested by `manage-skill`, use the skill's already selected scope
unless the user explicitly requests otherwise.

## 2. Choose the harness-neutral entry point

For a **local** rule, use the target repository's `AGENTS.md`, or the nearest
folder-level `AGENTS.md` when the rule applies only to that subtree. A longer
rule may live in a repository-relative Markdown file linked explicitly from
that entry point with instructions to read and apply it. Keep the rule in the
repository, not in the user's global configuration.

For a **global** rule in Enes's setup, locate and verify the `enesbala5/config`
checkout using the user's path, the resolved `~/.agents/skills` symlink, or
`~/config`. Use `misc/agents/AGENTS.md` as the neutral entry point. This repository
also requires a matching `misc/rules/general/<name>.mdc` with `alwaysApply: true`
for Cursor; follow its existing paired-rule convention and keep both aligned.
Do not replace existing instructions wholesale. Do not edit only a generated or
installed copy on a remote machine; propose a config-repo PR when the source
checkout is unavailable. Do not commit, push, or open a PR unless authorized.

Inspect symlinks before editing: a repository-local request must not write
through a symlink into global or external configuration. Stop and ask if the
requested scope cannot be honored safely.

## 3. Write portable instructions

Rules must work in any coding-agent harness, regardless of their location.
Use plain Markdown, repository-relative paths, documented environment variables,
and normal shell/Make/HTTP commands. Do not require a harness's internal tool,
MCP server, hook, plugin, or slash command; optional integrations need a complete
portable alternative. Document prerequisites and external-service access without
embedding credentials.

For skill discovery, name the skill and its canonical `SKILL.md` path in
`AGENTS.md` and state when to read it. Do not assume `/skill-name` executes in
all agents. Local skills belong in `.agents/skills/<name>/SKILL.md`; global
skills in this config repository belong in `misc/skills/<name>/SKILL.md`.
Read `manage-skill/SKILL.md` from the local or shared skills tree when creating
or changing a skill. If it is unavailable, report that instead of pretending a
slash command ran.

Harness-specific discovery files may be adapters, never the only rule source.
For a local repository, add an adapter only when needed for a known environment:
prefer a symlink or a short pointer to the neutral rule instead of duplicating
its body. Do not create `.cursor/` or `.claude/` copies by default. Preserve the
config repository's existing global paired-rule convention described above.

## 4. Verify the requested operation

- **Create/update:** ensure an agent can discover and follow the rule through
  `AGENTS.md` without a particular harness. Check referenced paths and required
  prerequisites. Preserve the intended directory scope and existing rules.
- **List:** report scope, entry points, and referenced rule files without edits.
- **Remove:** identify the precise section/file and adapters, confirm deletion,
  and remove only the approved rule and its references. Never delete an entire
  shared `AGENTS.md` merely to remove one rule.

Review the diff and any new files. Report changed paths, scope, portability
checks, and unverified behavior separately. Do not claim the current session or
another machine has reloaded instructions merely because files changed.
