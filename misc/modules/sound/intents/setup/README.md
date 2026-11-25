# Intent: setup

Owns provider, install, licence-policy and provenance questions that must be
settled before sound work. Trigger: "is the tool ready / can I use this clip" —
not a sound request (`make`) or a quality check (`verify`).

## Read first

`<config>/misc/modules/sound/AGENTS.md` owns the hard gates. Then, in order:
`<config>/misc/modules/sound/providers/README.md`,
`<config>/misc/modules/sound/rules/soundtrack/README.md`, the guide root
`<config>/misc/guides/sound/README.md`, and the named bucket `tooling-and-providers/`.

## Sequence

1. Choose the provider: `earshot` for making and listening, `real-sound` for the
   real-recordings soundtrack path.
2. Install the tool from its pinned GitHub source, run `earshot doctor`, and
   confirm the single interpreter has numpy, scipy, soundfile and `earshot`.
3. Apply the licence policy: allowed, forbidden, or unverified-and-blocked;
   confirm classification on the item's own page.
4. Point licence, provenance and attribution at their separate source of truth
   and record the attribution lines to carry.

## Gates

- An unverified licence blocks the clip until confirmed on that item's page.
- Attribution is carried into the credits and the video description.
- Scripts run with `-I` on one interpreter; no provider doc holds credentials.

## Rules applied

`<config>/misc/modules/sound/rules/soundtrack/README.md` — driven by the
`tooling-and-providers` bucket.

## Handoff

- Tool and licences ready → `make`, `verify` or `score`.
- Licence unresolved → blocked; ask the user for a verified source.

## Never

- Treat licence, provenance or attribution as an audio judgement, or install
  the PyPI package named `earshot` in place of the pinned GitHub source.
