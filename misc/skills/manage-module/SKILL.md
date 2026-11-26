---
name: manage-module
description: Build and maintain a repo-local agentic module — a thin skill router plus a misc/<name> workspace — from an evidence-backed guide's lessons. Use for initialize (new module from a guide), extend (add an intent, layer, stage or rule), suggest (flexibility review), and verify (structure check). Triggers include "turn this guide into a skill/module", "add an intent to this module", "audit this module's structure", "suggest improvements to this module".
---

# Manage module

A **module** is two things: a thin skill router (`.agents/skills/<name>/SKILL.md` locally, `<config>/misc/skills/<name>/SKILL.md` globally), and a workflow workspace (`misc/<name>/` locally, `<config>/misc/modules/<name>/` globally) holding hard gates, intents, rules and records. The evidence lives in a guide's lessons; the module holds **rules derived from that evidence**, never copies of it. Every module also declares its external backends in `providers/`; "No external providers" is a valid declaration.

This skill is self-contained. Its structure, templates and conventions are all in this folder. **Never point the agent at another repository, another project's workspace, or an existing module as something to read** — use only this skill's references and the target guide the user names.

Run **one intent at a time**. If the request is ambiguous, list the intents and ask. See [`reference/handoff.md`](reference/handoff.md) for the block used to chain intents and hand the router to `manage-skill`.

## Common parameters

| Parameter | Meaning | Resolution |
|---|---|---|
| `name` | Kebab-case module name; also the workspace folder name | Ask if missing; validate `[a-z0-9]+(-[a-z0-9]+)*` |
| `scope` | `global` or `local` — which roots own the module | Resolve **before any write**; default `local`. Do not re-ask when the request already answers it |
| `repo` | Repository to build into | Default current repo; ask if ambiguous |
| `guide` | Repository-relative lessons directory, e.g. `misc/guides/<topic>/` | Ask; never guess |
| `purpose` | Short noun phrase for what the module does | Ask; the intents depend on it |

**If a required parameter is missing, prompt the user interactively before writing anything** — offer concrete options where possible. Do not scaffold before the design is approved.

Resolve the repository root with `git rev-parse --show-toplevel`. Inspect `AGENTS.md` and `git status --short` first; preserve unrelated changes; never commit unless asked.

### Scope and destinations

Resolve `scope` before writing. Apply the same checkout checks as
`manage-skill`'s `intents/rules.md` sections "Scope resolution" and "Canonical
destination": verify the config checkout, keep one canonical copy, never edit a
symlinked install, and do not commit. Scope changes placement only.

| Piece | Global | Local |
| --- | --- | --- |
| Router skill | `<config>/misc/skills/<name>/SKILL.md` | `<repo>/.agents/skills/<name>/SKILL.md` |
| Workspace | `<config>/misc/modules/<name>/` | `<repo>/misc/<name>/` |
| Evidence guide | `<config>/misc/guides/<topic>/` | `<repo>/misc/guides/<topic>/` |
| Per-project records | `<repo>/misc/<name>/` in the working repo | `<repo>/misc/<name>/` |

`<config>` is the verified config checkout; `<repo>` is the working repository
root. A global module usually spans two repositories: rules, gates, intents and
evidence live under `<config>`, while per-project records live under `<repo>` so
projects from different repositories never mix. Write these roots as tokens in
generated files — no machine paths, and no Markdown links across the two roots.
Name the other root's path in backticks instead.

When the router is created, hand off to `manage-skill` with the resolved scope
already set so it does not re-ask "global or local?".

## Intents

| Intent | Extra parameters | Result |
|---|---|---|
| [`initialize`](intents/initialize.md) | `intents` (approved list), `layers`, `stages` | Scaffold the workspace, fill gates/rules/intents, hand the router to `manage-skill` |
| [`extend`](intents/extend.md) | `target`, `change` | Add an intent, layer, stage, rule, provider or record shape; update the owning index |
| [`suggest`](intents/suggest.md) | `focus` (optional) | Tailored flexibility proposals from [`reference/flexibility.md`](reference/flexibility.md); stop for approval |
| [`verify`](intents/verify.md) | — | Read-only structure/link check; hands fixes to `extend` |

## Hard rules

- Router only picks an intent and names one file to read. All rules live in the workspace.
- One intent per request; `verify` is read-only and hands fixes to `extend`.
- Nested files add or override; they never restate an ancestor. Load a read-chain, never a whole tree.
- Rules say what must be true; lessons are the evidence. Keep them in separate files and link rule → lesson path. When a lesson materially informs a module change, append its repository-relative path and date to `CONSUMED-LESSONS.yml`; do not record mere reading.
- No absolute machine paths; use `<config>` / `<repo>` tokens and never link across the two roots.
- No references to other repositories as sources of truth, and no copied lesson text.
- Every module ships `providers/README.md`. A backend is added with `extend` (`target: provider`) and documented minimally: what it supplies, how it is reached, what it costs; gates stay in `AGENTS.md`.
- Do not commit unless asked.

## Verification

Every write ends with `node scripts/verify-module.js <root> <name> --scope <scope>`, which checks router rows vs intent folders, required files, token and relative paths, and that nothing points outside the module's root. Report files created, decisions made, and anything deferred.

## Failure handling

- Guide missing or empty → stop and ask for a valid path; do not invent rules.
- Design not approved → do not scaffold.
- Router creation fails → report it explicitly; a workspace without a router is not a working module.
