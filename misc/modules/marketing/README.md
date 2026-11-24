# marketing workspace

own marketing strategy and hand content to copy and visuals to design

Evidence lives in `<config>/misc/guides/marketing/`. The rules here derive from
those lessons; the lessons themselves stay unchanged. Read
`<config>/misc/modules/marketing/AGENTS.md` first for the hard gates.

Router: `<config>/misc/skills/marketing/SKILL.md`.

## Scope

Marketing strategy only: research, positioning, offers, channels, launch and
experiments. Content execution is the `copy` module's job; visual and layout
execution is the `design` module's job. This module produces the brief and the
boundary, then hands off.

## Intents

- **research** — `<config>/misc/modules/marketing/intents/research/README.md`
- **position** — `<config>/misc/modules/marketing/intents/position/README.md`
- **plan** — `<config>/misc/modules/marketing/intents/plan/README.md`
- **handoff** — `<config>/misc/modules/marketing/intents/handoff/README.md`
- **verify** — `<config>/misc/modules/marketing/intents/verify/README.md`

## Layers in use

- `rules/` — eight rule sets mirroring the guide buckets; each rule names its
  evidence and never copies lesson prose. Justified by the 157-lesson guide and
  the number of domain rules that would otherwise bloat `AGENTS.md`.

## Providers

`<config>/misc/modules/marketing/providers/README.md` declares external backends —
what they supply, how they are reached and what they cost. "No external providers"
is a valid declaration.

## Rules

Rules live in `<config>/misc/modules/marketing/rules/README.md`, split into eight
sets: `research`, `positioning`, `offers`, `channels`, `launch`, `experiments`,
`handoffs`, `mistakes`. Each rule states what must be true and points to lesson
evidence; it never copies lesson text.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews
live in `<repo>/misc/marketing/` in the working repository, so projects from
different repositories never mix. Name that path; never link across roots.

## Findings

`<config>/misc/modules/marketing/LEARNINGS.md` holds conclusions from real work
with a status. Guide lessons do not change when a finding is verified.

## Not yet needed

- `references/` — add when a pinned contract or template is needed.
- `pipeline/` — add only if the five intents become one ordered pipeline with
  named stages; the intents already encode the order.
- `projects/` — add only if the module itself needs per-target records; today
  records live in `<repo>/misc/marketing/`.
