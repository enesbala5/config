# {{NAME}} workspace

This is a workflow workspace, not a lesson library. Evidence-backed lessons stay
in `{{GUIDE_PATH}}`. This folder holds hard gates, intent entries, and findings
from applying the guides to real work.

This file holds the hard gates only: one intent, where records live, authority,
approval, and the read-chain. Everything else is loaded per intent.

## Start here

Read the router at `{{ROUTER_PATH}}`. It is the only auto-loaded `{{NAME}}` skill
and routes to one intent:

{{INTENT_LIST}}

A rule is what must be true; a lesson in `{{GUIDE_PATH}}` is the evidence behind
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

{{RECORDS_RULE}}

## Providers

External backends are declared in {{PROVIDERS_LINK}}. "No external providers"
is a valid declaration; a backend is added with `extend` (`target: provider`).
Gates for using one live here, not in the provider docs.

## Authority

_{{State what owns the real decisions here — for example a product spec, a
system definition, or an explicit user approval. Do not invent defaults when
that authority is absent: say so and ask._

## Approval

_{{State the gate: what must be approved before work changes, and what counts as
done. A read-only verify intent never edits._
