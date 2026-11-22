---
name: manage-module
description: Build and maintain a repo-local agentic module — a thin skill router plus a misc/<name> workspace — from an evidence-backed guide's lessons. Use for initialize (new module from a guide), extend (add an intent, layer, stage or rule), suggest (flexibility review), and verify (structure check). Triggers include "turn this guide into a skill/module", "add an intent to this module", "audit this module's structure", "suggest improvements to this module".
---

# Manage module

A **module** is two things: a thin skill router at `.agents/skills/<name>/SKILL.md`, and a workflow workspace at `misc/<name>/` holding hard gates, intents, rules and records. The evidence lives in a guide's lessons; the module holds **rules derived from that evidence**, never copies of it.

This skill is self-contained. Its structure, templates and conventions are all in this folder. **Never point the agent at another repository, another project's workspace, or an existing module as something to read** — use only this skill's references and the target guide the user names.

Run **one intent at a time**. If the request is ambiguous, list the intents and ask. See [`reference/handoff.md`](reference/handoff.md) for the block used to chain intents and hand the router to `manage-skill`.

## Common parameters

| Parameter | Meaning | Resolution |
|---|---|---|
| `name` | Kebab-case module name; also the workspace folder name | Ask if missing; validate `[a-z0-9]+(-[a-z0-9]+)*` |
| `repo` | Repository to build into | Default current repo; ask if ambiguous |
| `guide` | Repository-relative lessons directory, e.g. `misc/guides/<topic>/` | Ask; never guess |
| `purpose` | Short noun phrase for what the module does | Ask; the intents depend on it |

**If a required parameter is missing, prompt the user interactively before writing anything** — offer concrete options where possible. Do not scaffold before the design is approved.

Resolve the repository root with `git rev-parse --show-toplevel`. Inspect `AGENTS.md` and `git status --short` first; preserve unrelated changes; never commit unless asked.

## Intents

| Intent | Extra parameters | Result |
|---|---|---|
| [`initialize`](intents/initialize.md) | `intents` (approved list), `layers`, `stages` | Scaffold the workspace, fill gates/rules/intents, hand the router to `manage-skill` |
| [`extend`](intents/extend.md) | `target`, `change` | Add an intent, layer, stage, rule or record shape; update the owning index |
| [`suggest`](intents/suggest.md) | `focus` (optional) | Tailored flexibility proposals from [`reference/flexibility.md`](reference/flexibility.md); stop for approval |
| [`verify`](intents/verify.md) | — | Read-only structure/link check; hands fixes to `extend` |

## Hard rules

- Router only picks an intent and names one file to read. All rules live in the workspace.
- One intent per request; `verify` is read-only and hands fixes to `extend`.
- Nested files add or override; they never restate an ancestor. Load a read-chain, never a whole tree.
- Rules say what must be true; lessons are the evidence. Keep them in separate files and link rule → lesson path.
- No absolute machine paths, no references to other repositories, no copied lesson text.
- Do not commit unless asked.

## Verification

Every write ends with `node scripts/verify-module.js <repo> <name>`, which checks relative links, router rows vs intent folders, required files, and that nothing points outside the target repo. Report files created, decisions made, and anything deferred.

## Failure handling

- Guide missing or empty → stop and ask for a valid path; do not invent rules.
- Design not approved → do not scaffold.
- Router creation fails → report it explicitly; a workspace without a router is not a working module.
