# sound workspace

strategy for sound design and audio verification, not content

Evidence lives in `<config>/misc/guides/sound/`. The rules here derive from those lessons; the
lessons themselves stay unchanged. Read `<config>/misc/modules/sound/AGENTS.md` first for the
hard gates.

Router: `<config>/misc/skills/sound/SKILL.md`.

## Intents

- **make** — `<config>/misc/modules/sound/intents/make/README.md`
- **verify** — `<config>/misc/modules/sound/intents/verify/README.md`
- **score** — `<config>/misc/modules/sound/intents/score/README.md`
- **place** — `<config>/misc/modules/sound/intents/place/README.md`
- **setup** — `<config>/misc/modules/sound/intents/setup/README.md`

`verify` is read-only and hands fixes to the change intents.

## Layers in use

- pipeline/ — the real-recordings soundtrack is a gated, multi-step workflow; stages are the named steps and only route, never copy lessons.
- rules/ — 57 lessons across six buckets produce domain rules; they live in rule sets that point back to bucket evidence.

## Providers

`<config>/misc/modules/sound/providers/README.md` declares external backends — what they supply, how they are
reached and what they cost. "No external providers" is a valid declaration.

## Rules

`<config>/misc/modules/sound/rules/README.md` indexes three sets: acquire, evidence and soundtrack.
Each rule is one enforceable statement with an evidence pointer; lesson prose stays in the guide.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews live in `<repo>/misc/sound/` in the working repository, so projects from different repositories never mix. Name that path; never link across roots.

## Findings

`<config>/misc/modules/sound/LEARNINGS.md` holds conclusions from real work with a status.
Guide lessons do not change when a finding is verified.

## Not yet needed

- `projects/` — add when record shapes must be shared across more than one working repository; today AGENTS.md only names `<repo>/misc/sound/`.
- `references/` — add when capture formats or templates outgrow the provider index.
