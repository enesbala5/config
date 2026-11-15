---
name: manage-skill
description: Create, install, update, list, or remove agent skills with explicit global or repository-local scope. Use for /manage-skill, "create a skill", "save this as a skill", or requests to install a skill in a repository. All created or edited skills must be harness-agnostic, regardless of scope.
---

# Manage skills

Treat `/manage-skill` as a request for this workflow, not a required harness
command. Any agent can follow this file directly using ordinary file and shell
operations.

## 1. Resolve the operation and scope

Inspect the target repository's `AGENTS.md`, existing skill conventions, and
`git status --short`. Preserve unrelated changes. Resolve the repository root
with `git rev-parse --show-toplevel`; outside git, ask for the project directory.

Honor scope already specified by the user:

- **Local / project / repository-scoped / installed in this repository:** use
  `<repository>/.agents/skills/<name>/SKILL.md`. This is the local case even when
  the repository happens to be `enesbala5/config`.
- **Global / shared across projects:** use
  `<config-checkout>/misc/skills/<name>/SKILL.md` in `enesbala5/config`.

If scope is missing or ambiguous, ask "Global, or local to this repository?"
and wait before choosing a destination or writing files. Do not ask again when
the request already answers this question. Scope changes placement only; it
never relaxes the harness-agnostic requirements below.

For an update, list, or removal, inspect the requested scope first. If a name
exists in both scopes and the user has not identified one, ask which copy they
mean. Do not silently edit the global copy instead of the local one.

## 2. Resolve the canonical destination

For local skills, write only under the target repository's `.agents/skills/`.
Do not install them in `misc/skills/`, a home directory, `.cursor/skills/`, or
`.claude/skills/`. Check that `.agents/skills` does not resolve through a symlink
outside the target repository before writing; if it does, stop and ask for a
repository-local destination. Do not change that symlink automatically.

For global skills, locate the `enesbala5/config` checkout from the user's
explicit path, the resolved `~/.agents/skills` symlink, or `~/config`. Verify the
checkout before editing; do not assume the current repository is the config
repo. On Framework 13, Home Manager live-symlinks `~/.agents/skills` to its
`misc/skills` directory. Edit the tracked source, not a disposable installed copy.
On remote/cloud machines without a config checkout, propose adding the skill
through a PR to `enesbala5/config`; do not silently save a global skill only in
the remote home directory. Do not clone, commit, push, or open a PR without user
authorization.

Use a lowercase kebab-case name matching `[a-z0-9]+(-[a-z0-9]+)*`; reject paths,
slashes, and `..`. Inspect existing files and symlinks before overwriting. Keep
one canonical copy. Only add a harness discovery symlink or pointer when needed
for a known environment; never duplicate the implementation.

## 3. Create, install, or edit a portable skill

Every created or edited skill MUST be harness-agnostic, whether global or local.
Apply this gate to imported skills too: inspect them before installing, adapt
harness-specific instructions when authorized, or report the incompatibility.
Do not install a non-portable skill unchanged and call it compliant.

A skill is a plain folder containing `SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: What it does and when an agent should use it.
---
```

Write actionable Markdown instructions with inputs, prerequisites, steps,
verification, and failure handling. Supporting scripts, templates, and references
belong inside the same folder. Resolve their paths relative to the skill's own
directory, not the agent's current working directory.

### Mandatory portability gate — both scopes

- Use open conventions: `AGENTS.md`, a folder with `SKILL.md`, and ordinary
  shell, Make, or HTTP commands. Do not require a particular harness's tool
  names, APIs, plugins, hooks, or slash-command expansion.
- A harness tool or MCP integration may be an optional convenience only. Give
  a complete CLI/HTTP/file-based alternative, including prerequisites and the
  same verification; "use another tool" is not an alternative.
- Document external services with endpoints, authentication environment-variable
  names, setup commands, and failure behavior. Never embed secrets. An
  environment-specific task is allowed; requiring one agent harness to execute
  it is not.
- Avoid machine-specific absolute paths. Use repository-relative paths,
  skill-relative assets, or documented configuration. Keep the skill usable
  when moved between the global and local locations.
- Put non-obvious project conventions, required variables, startup steps, and
  discovery pointers in the nearest `AGENTS.md`. Use `manage-rule` for persistent
  rules rather than hiding always-on requirements inside an optional skill.
  Read its `SKILL.md` from the repository-local or shared skills tree; if it is
  unavailable, report that instead of assuming `/manage-rule` will execute.

The requirements above are self-contained; applying them must not depend on a
config checkout, a Cursor `.mdc` file, network access, or another harness.

## 4. Handle the other operations

- **List:** report names, descriptions, canonical paths, and scope without
  modifying files. Distinguish local and global copies.
- **Update:** change only the requested skill and repeat the portability gate.
  Report any unresolved incompatibility; do not claim full portability based
  only on correct frontmatter.
- **Remove:** identify the exact canonical directory and any discovery links,
  confirm the deletion target, and remove only the approved files. Do not follow
  symlinks into another scope or remove shared dependencies.

## 5. Verify and report

Before declaring a create/install/update complete:

1. Verify the destination matches the requested scope, the YAML is valid, `name`
   matches the directory, and `description` explains both purpose and triggers.
2. Walk through the instructions as an agent in a different harness with only
   filesystem, shell, and documented service access. Check every required step,
   supporting path, and fallback; run safe checks where practical. Distinguish
   inspection from commands actually tested.
3. Confirm there is one canonical implementation and that any needed `AGENTS.md`
   discovery/rule updates were handled through `manage-rule`.
4. Review `git diff` and new files for unrelated changes and credentials. Report
   the scope, canonical path, portability checks, and anything unverified. Do
   not commit or publish unless requested.

### Acceptance cases

- "Create a local skill in this repo" → write `.agents/skills/<name>/SKILL.md`,
  without a redundant scope question or a global installation.
- "Create a global skill" → write `misc/skills/<name>/SKILL.md` in the verified
  config checkout, not the current unrelated repository.
- "Create a skill" → ask for scope before writing anything.
- A local or global draft requires an MCP tool or a harness slash command →
  provide a working portable alternative or report it as blocked; neither scope
  is an exception.
- A skill needs an always-on project rule → use `manage-rule` with repository
  scope; keep the rule discoverable through `AGENTS.md`, not only Cursor config.
