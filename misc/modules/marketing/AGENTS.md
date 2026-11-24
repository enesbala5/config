# marketing workspace

This is a workflow workspace, not a lesson library. Evidence-backed lessons stay
in `<config>/misc/guides/marketing/`. This folder holds hard gates, intent entries,
and findings from applying the guide to real work.

This file holds the hard gates only: one intent, where records live, authority,
approval, and the read-chain. Everything else is loaded per intent.

## Start here

Read the router at `<config>/misc/skills/marketing/SKILL.md`. It is the only
auto-loaded `marketing` skill and routes to one intent:

- **research** — `<config>/misc/modules/marketing/intents/research/README.md`
- **position** — `<config>/misc/modules/marketing/intents/position/README.md`
- **plan** — `<config>/misc/modules/marketing/intents/plan/README.md`
- **handoff** — `<config>/misc/modules/marketing/intents/handoff/README.md`
- **verify** — `<config>/misc/modules/marketing/intents/verify/README.md`

A rule is what must be true; a lesson in `<config>/misc/guides/marketing/` is the
evidence behind it. Never mix the two roles in one file.

## Hard gates

1. **Strategy only.** Produce decisions, briefs and plans. Never write copy or
   visual/layout direction, and never post, schedule or publish. Hand content to
   the `copy` module and visual execution to the `design` module.
2. **No invented inputs.** Audience, voice, offer, pricing, claims and product
   context come from the human or cited evidence. When one is absent, ask and stop.
3. **Evidence floor.** No persona or messaging conclusion from fewer than five
   independent data points per segment. Label confidence and never invent persona
   fields.
4. **Claims boundary.** No unverifiable outcome guarantees or "beat the system"
   claims. State claims and anti-claims explicitly; treat the status quo as the
   main competitor.
5. **Positioning before copy.** Copy is gated on an approved positioning brief,
   campaign angle and locked tone. Strategy writes the brief, not the words.
6. **Valid tests.** Pre-commit hypothesis, sample, duration and metric tiers; one
   variable per test; no early stopping; pre-register segments.
7. **Honest levers.** Use scarcity only when the constraint is real; judge
   short-term tactics by their second-order effects.
8. **Records and read-only verify.** Drafts, decisions and reviews live in
   `<repo>/misc/marketing/` in the working repository. `verify` never edits.

## Nested files: read the chain

Applies to every nested tree here — `intents/`, `pipeline/`, `projects/`,
`references/` and `rules/` — and to the guide tree.

- A file does not link to its parents or claim a parent "applies". The reader
  loads the chain, root first, ending at the file the task names: the tree's
  index, each ancestor's index, then the file itself. Cross-file references use
  the root-anchored tokens below, never `../` chains.
- A nested file only adds or overrides. Do not restate an ancestor. If a rule is
  missing in the leaf, the nearest ancestor's rule still holds.
- Never read a whole bucket of lessons, and never open a second sibling branch
  for the same task.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews
live in `<repo>/misc/marketing/` in the working repository, so projects from
different repositories never mix. Name that path; never link across roots. Use a
stable kebab-case slug per strategy artifact and keep the human name as a field.

## Providers

External backends are declared in `<config>/misc/modules/marketing/providers/README.md`.
"No external providers" is a valid declaration; a backend is added with `extend`
(`target: provider`). Gates for using one live here, not in the provider docs.

## Authority

The human's supplied product-marketing context owns the strategy: audience and
pain points, product capabilities, offer and pricing decisions, voice sources,
claims boundaries, and real receipts. When one is absent, ask and stop; no default
audience, offer, claim or channel is invented. Project marketing context in the
working repository (for example `docs/marketing/`) is project truth, not guide
evidence. Guide lessons own the evidence; these rules own how the module applies it.

## Approval

Strategy artifacts stay drafts until the human accepts them. Positioning, angle,
offer, claims and channel plan are approved before any handoff to `copy` or
`design`. `verify` is read-only: it reports and hands fixes to the owning intent.
The module never publishes, schedules, posts, or generates copy or visual assets.
