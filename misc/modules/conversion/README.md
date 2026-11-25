# Conversion workspace

Audit conversion surfaces and lifecycle flows, plan email sequences, and verify
changes and tests, using rules derived from the lessons in
`<config>/misc/guides/conversion/`.

Evidence lives in `<config>/misc/guides/conversion/`. The rules here derive from
those lessons; the lessons themselves stay unchanged. Read
`<config>/misc/modules/conversion/AGENTS.md` first for the hard gates.

Router: `<config>/misc/skills/conversion/SKILL.md`.

## Intents

- **audit** — `<config>/misc/modules/conversion/intents/audit/README.md` —
  diagnose a page, form, onboarding or paywall surface and recommend fixes.
- **plan** — `<config>/misc/modules/conversion/intents/plan/README.md` —
  design a lifecycle email sequence and any follow-on design decision.
- **verify** — `<config>/misc/modules/conversion/intents/verify/README.md` —
  read-only check of a test, claim or anti-pattern, with fixes handed back.

## Layers in use

- `rules/` — domain rules are numerous and reusable across intents, so they live
  in indexed rule sets rather than in intent entries. This is the only optional
  layer in use.

## Providers

`<config>/misc/modules/conversion/providers/README.md` declares external
backends — what they supply, how they are reached and what they cost. It
currently declares no external providers.

## Rules

`<config>/misc/modules/conversion/rules/README.md` indexes the three rule sets —
diagnosis, design and verification. Rules state what must be true and point to
lesson evidence; they never copy lesson text.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews
live in `<repo>/misc/conversion/` in the working repository, so projects from
different repositories never mix. Name that path; never link across roots.

## Findings

`<config>/misc/modules/conversion/LEARNINGS.md` holds conclusions from real work
with a status. Guide lessons do not change when a finding is verified.

## Not yet needed

- `pipeline/` — add only if work needs stage-by-stage lesson routing with
  per-stage overrides; the three intents currently map directly to buckets.
- `projects/` — add only if per-target state must live in the shared workspace
  instead of `<repo>/misc/conversion/`.
- `references/` — add only if reusable capture formats or templates are needed
  for findings and plans.
