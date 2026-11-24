# copy workspace

write, edit, and publish copy for web pages, X posts, comment replies, and technical blog posts

Evidence lives in `<config>/misc/guides/copy/`. The rules here derive from those lessons; the
lessons themselves stay unchanged. Read `<config>/misc/modules/copy/AGENTS.md` first for the
hard gates.

Router: `<config>/misc/skills/copy/SKILL.md`.

## Intents

- **write** — `<config>/misc/modules/copy/intents/write/README.md`
- **revise** — `<config>/misc/modules/copy/intents/revise/README.md`
- **social** — `<config>/misc/modules/copy/intents/social/README.md`
- **longform** — `<config>/misc/modules/copy/intents/longform/README.md`
- **verify** — `<config>/misc/modules/copy/intents/verify/README.md`

## Layers in use

- `rules/` — domain rules are numerous and need per-surface sets with lesson evidence, not a single manual in `AGENTS.md`.
- `references/` — re-homed frameworks, checklists, source registers and pinned tool/output contracts, read only when an intent names them.

## Providers

`<config>/misc/modules/copy/providers/README.md` declares external backends — what they supply, how they are
reached and what they cost. "No external providers" is a valid declaration.

## Rules

Rules live in `<config>/misc/modules/copy/rules/README.md`, split into five sets:
`page-copy`, `editing`, `social`, `longform`, `cross-cutting`. Each rule states
what must be true and links to lesson evidence; it never copies lesson text.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews live in `<repo>/misc/copy/` in the working repository, so projects from different repositories never mix. Name that path; never link across roots.

## Findings

`<config>/misc/modules/copy/LEARNINGS.md` holds conclusions from real work with a status.
Guide lessons do not change when a finding is verified.

## Not yet needed

- `pipeline/` — add only if the five intents become one ordered pipeline with named stages.
- `projects/` — add only if the module itself needs per-target records; today records live in `<repo>/misc/copy/`.
