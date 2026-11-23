---
name: manage-skill
description: Create, install, update, list, move, or remove agent skills with explicit global or repository-local scope. Use for /manage-skill, "create a skill", "save this as a skill", "move this skill to this repo", or requests to install a skill in a repository. All created or edited skills must be harness-agnostic, regardless of scope. Module-shaped requests route to manage-module.
---

# Manage skills

This router only picks one intent and names the one file to read next. All rules
live under [`./intents/`](intents/): the single shared
[`rules.md`](intents/rules.md) holds scope resolution, canonical paths, the
portability gate, and verify/report; each intent folder adds only its own
operation. Nothing here restates the procedure.

## Pick one intent

| The user wants | Intent | Read |
| --- | --- | --- |
| Create or install a skill, including an import | `create` | [`intents/create/README.md`](intents/create/README.md) |
| Change an existing skill's content or frontmatter | `update` | [`intents/update/README.md`](intents/update/README.md) |
| List skills, their scopes and canonical paths | `list` | [`intents/list/README.md`](intents/list/README.md) |
| Move a skill between scopes or repositories | `move` | [`intents/move/README.md`](intents/move/README.md) |
| Remove a skill | `delete` | [`intents/delete/README.md`](intents/delete/README.md) |

`list` and `update` are kept as two first-class intents with their own files,
not a single shared rule file. Module-shaped requests — a thin router plus a
workspace derived from guide lessons (`<config>/misc/modules/<name>/` globally,
`misc/<name>/` locally) — route to `manage-module`, not here.

Stop after naming the intent and reading its file. The intent file and
`intents/rules.md` own the next step, including any required confirmation,
writes, and verification.
