# Conversion workspace

This is a workflow workspace, not a lesson library. Evidence-backed lessons stay
in `<config>/misc/guides/conversion/`. This folder holds hard gates, intent
entries, and findings from applying those lessons to real work.

This file holds the hard gates only: one intent, where records live, authority,
approval, and the read-chain. Everything else is loaded per intent.

## Start here

Read the router at `<config>/misc/skills/conversion/SKILL.md`. It is the only
auto-loaded `conversion` skill and routes to one intent:

- **audit** — `<config>/misc/modules/conversion/intents/audit/README.md`
- **plan** — `<config>/misc/modules/conversion/intents/plan/README.md`
- **verify** — `<config>/misc/modules/conversion/intents/verify/README.md`

A rule is what must be true; a lesson in `<config>/misc/guides/conversion/` is
the evidence behind it. Never mix the two roles in one file.

## Hard gates

1. **Diagnose before prescribe.** No recommendation without a finding and
   evidence; state impact and priority.
2. **Aha before ask.** A user must experience core value before any upgrade or
   paywall ask.
3. **One goal per surface.** One primary action per page, form, step or email.
4. **Honest levers only.** No fake urgency, dark patterns or trapping; respect
   dismissal.
5. **Valid tests.** Pre-commit the hypothesis, define metric tiers and change one
   variable; no early stopping.
6. **Email supports, never duplicates in-app.** Email reinforces the in-app flow
   rather than repeating it.
7. **Boundary.** No copy or visual/layout direction — hand to `copy`/`design`.
   Never publish, schedule or send.
8. **Records and read-only verify.** Records live in `<repo>/misc/conversion/`.
   `verify` never edits.

## Nested files: read the chain

Applies to every nested tree here — `intents/` and `rules/` — and to the guide
tree.

- A file does not link to its parents or claim a parent "applies". The reader
  loads the chain, root first, ending at the file the task names: the tree's
  index, each ancestor's index, then the file itself. Cross-file references
  use the root-anchored tokens below, never `../` chains.
- A nested file only adds or overrides. Do not restate an ancestor. If a rule
  is missing in the leaf, the nearest ancestor's rule still holds.
- Never read a whole bucket of lessons, and never open a second sibling branch
  for the same task.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews
live in `<repo>/misc/conversion/` in the working repository, so projects from
different repositories never mix. Name that path; never link across roots.

## Providers

External backends are declared in
`<config>/misc/modules/conversion/providers/README.md`. "No external providers"
is a valid declaration; a backend is added with `extend` (`target: provider`).
Gates for using one live here, not in the provider docs.

## Authority

Measured user data and the user's explicit approval own decisions here. Guide
lessons are evidence, not authority. Where data or approval is absent, ask — do
not assume a goal, metric or audience.

## Approval

Present a diagnosis and ranked recommendations for approval before treating any
as decided; approve direction before handing copy or design work off. Done means
findings or a plan are recorded under `<repo>/misc/conversion/`, or a read-only
verdict is issued with fixes handed back. A read-only verify intent never edits.
