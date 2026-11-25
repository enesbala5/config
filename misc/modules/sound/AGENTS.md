# sound workspace

This is a workflow workspace, not a lesson library. Evidence-backed lessons stay
in `<config>/misc/guides/sound/`. This folder holds hard gates, intent entries, and findings
from applying the guides to real work.

This file holds the hard gates only: one intent, where records live, authority,
approval, and the read-chain. Everything else is loaded per intent.

## Start here

Read the router at `<config>/misc/skills/sound/SKILL.md`. It is the only auto-loaded `sound` skill
and routes to one intent:

- **make** — `<config>/misc/modules/sound/intents/make/README.md`
- **verify** — `<config>/misc/modules/sound/intents/verify/README.md`
- **score** — `<config>/misc/modules/sound/intents/score/README.md`
- **place** — `<config>/misc/modules/sound/intents/place/README.md`
- **setup** — `<config>/misc/modules/sound/intents/setup/README.md`

A rule is what must be true; a lesson in `<config>/misc/guides/sound/` is the evidence behind
it. Never mix the two roles in one file.

## Hard gates

Always-on; domain detail lives in `rules/` and in the named stage files.

1. Never claim how audio sounds, or that it fits, without a quoted earshot reading. Measurements outrank verdicts, `z` and probabilities; cosine is never a confidence. (evidence bucket: `listening`)
2. A stand-in line is a hard stop — build the thing or declare it missing; never pass a stand-in off as the thing. (evidence bucket: `making-sounds`)
3. The licence gate is explicit: unverified is blocked; audit must exit 0 for exactly what is used; attribution must be carried. (evidence bucket: `tooling-and-providers`)
4. No pipeline gate may be skipped to finish faster; each step hands a concrete artifact and passes its gate. (evidence bucket: `film-sound`)
5. A master is accepted only when measured inside the gate: -14 LUFS ±0.5, ≤ -1.5 dBTP, and ≤ -1 dBTP after codec. (evidence bucket: `film-sound`)
6. Upload critique needs explicit per-call user consent; never pass consent on your own. State plainly what was not checked or cannot be judged. (evidence bucket: `placement-and-limits`)

## Nested files: read the chain

Applies to every nested tree here — `intents/`, `pipeline/` and `rules/` — and to the guide tree.

- A file does not link to its parents or claim a parent "applies". The reader loads the chain, root first, ending at the file the task names: the tree's index, each ancestor's index, then the file itself. Cross-file references use the root-anchored tokens below, never `../` chains.
- A nested file only adds or overrides. Do not restate an ancestor. If a rule is missing in the leaf, the nearest ancestor's rule still holds.
- Never read a whole bucket of lessons, and never open a second sibling branch for the same task.

## Records

This shared workspace holds no per-project state. Drafts, decisions and reviews live in `<repo>/misc/sound/` in the working repository, so projects from different repositories never mix. Name that path; never link across roots.

## Providers

External backends are declared in `<config>/misc/modules/sound/providers/README.md`. "No external providers"
is a valid declaration; a backend is added with `extend` (`target: provider`).
Gates for using one live here, not in the provider docs.

## Authority

The user's brief and explicit approval own real decisions here. Provider readings
are evidence, not authority: a model score cannot override an explicit user choice.
Where no authority is stated, ask rather than invent one.

## Approval

Name an intent and pass its gates before changing artifacts. Approval is required
before anything uploads audio, spends credits, or changes a shared soundtrack design.
Done means the named artifact exists and its gate passed, measured where measurable.
`verify` is read-only: it reports and hands fixes to the change intent; it never edits.
