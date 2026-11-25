# Intent: score

Owns a film, motion-video or real-footage soundtrack. Trigger: "score this clip"
or "build the soundtrack" — a gated pipeline, not a single sound (`make`).

## Read first

`<config>/misc/modules/sound/AGENTS.md` owns the hard gates. Then, in order:
`<config>/misc/modules/sound/pipeline/README.md`, the single named stage README,
`<config>/misc/modules/sound/rules/soundtrack/README.md`, the guide root
`<config>/misc/guides/sound/README.md`, and the named buckets `film-sound/` and
`tooling-and-providers/`. Never read a whole bucket or two sibling stages at once.

## Sequence

1. Walk the pipeline stages in order: cue, brief, source, audit, music, design,
   integrate, qa, critique, fix, master. Each hands a concrete artifact and
   passes its gate.
2. Use the `real-sound` provider for the real-recordings path; a code-synthesized
   bank is an alternative when the film does not need recorded sound.
3. Run measured QA and five read-only critics; one fixer merges and applies,
   with no QA regression.
4. Master to the measured gate, then close with credits and the mux.

## Gates

- No gate is skipped to reach the film faster, and no step changes the shared
  design without its owner.
- Licence audit exits 0 for exactly what the film uses, with attribution carried.
- Master passes the measured loudness gate; a value outside it is a fail.

## Rules applied

`<config>/misc/modules/sound/rules/soundtrack/README.md` — driven by the
`film-sound` and `tooling-and-providers` buckets.

## Handoff

- Stage gate fails → fix inside that stage, or return the artifact to its owning
  agent; never skip ahead.
- All gates pass and the mux has zero lag → done.
- Provider or licence gap → `setup`.

## Never

- Let multiple agents edit the shared design, or use a listen in place of the
  measured master gate.
