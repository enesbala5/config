# copy workspace

This is a workflow workspace, not a lesson library. Evidence-backed lessons stay
in `<config>/misc/guides/copy/`. This folder holds hard gates, intent entries, and findings
from applying the guides to real work.

This file holds the hard gates only: one intent, where records live, authority,
approval, and the read-chain. Everything else is loaded per intent.

## Start here

Read the router at `<config>/misc/skills/copy/SKILL.md`. It is the only auto-loaded `copy` skill
and routes to one intent:

- **write** — `<config>/misc/modules/copy/intents/write/README.md`
- **revise** — `<config>/misc/modules/copy/intents/revise/README.md`
- **social** — `<config>/misc/modules/copy/intents/social/README.md`
- **longform** — `<config>/misc/modules/copy/intents/longform/README.md`
- **verify** — `<config>/misc/modules/copy/intents/verify/README.md`

A rule is what must be true; a lesson in `<config>/misc/guides/copy/` is the evidence behind
it. Never mix the two roles in one file.

## Nested files: read the chain

Applies to every nested tree here — `intents/`, `pipeline/`, `projects/`,
`references/` and `rules/` — and to the guide tree.

- A file does not link to its parents or claim a parent "applies". The reader
  loads the chain, root first, ending at the file the task names: the tree's
  index, each ancestor's index, then the file itself. Cross-file references
  use the root-anchored tokens below, never `../` chains.
- A nested file only adds or overrides. Do not restate an ancestor. If a rule
  is missing in the leaf, the nearest ancestor's rule still holds.
- Never read a whole bucket of lessons, and never open a second sibling branch
  for the same task.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews live in `<repo>/misc/copy/` in the working repository, so projects from different repositories never mix. Name that path; never link across roots.

## Providers

External backends are declared in `<config>/misc/modules/copy/providers/README.md`. "No external providers"
is a valid declaration; a backend is added with `extend` (`target: provider`).
Gates for using one live here, not in the provider docs.

## Authority

The human's supplied inputs own each piece of copy: the five page-copy inputs,
product-marketing context, voice sources, and real receipts. Where one is
absent, ask and stop — no default audience, voice, or setup is invented. Guide
lessons own the evidence; these rules own how the module applies it.

## Approval

Copy stays a draft until the human accepts it. This module never posts,
schedules, publishes, or generates image assets. High-stakes copy needs the
expert-panel gate before handoff. `verify` is read-only: it reports and hands
fixes back to the owning intent. A source skill is deleted only after its
rules and evidence are captured and the user confirms its exact path.
