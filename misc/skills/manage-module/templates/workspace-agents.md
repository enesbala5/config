# {{NAME}} workspace

This is a workflow workspace, not a lesson library. Evidence-backed lessons stay
in `{{GUIDE}}/`. This folder holds hard gates, intent entries, and findings from
applying the guides to real work.

This file holds the hard gates only: one intent, where records live, authority,
approval, and the read-chain. Everything else is loaded per intent.

## Start here

Read the `{{NAME}}` skill router, then pick exactly one intent:

{{INTENT_LIST}}

## Nested files: read the chain

Applies to every nested tree here.

- A file does not link to its parents or claim a parent "applies". The reader
  loads the chain root first, ending at the file the task names: this
  `README.md`, this `AGENTS.md`, the relevant index, then the named file.
- A nested file only adds or overrides. Do not restate an ancestor. If a rule
  is missing in the leaf, the nearest ancestor's rule still holds.
- Never read a whole bucket of lessons, and never open a second sibling branch
  for the same task.

## Authority

_{{State what owns the real decisions here — for example a product spec, a
system definition, or an explicit user approval. Do not invent defaults when
that authority is absent: say so and ask._

## Approval

_{{State the gate: what must be approved before work changes, and what counts as
done. A read-only verify intent never edits._

## Records

_{{If the module is stateful, name where records live and what index tracks
them. Otherwise state "This module is stateless."}_
