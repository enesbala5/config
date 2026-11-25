# Intent: make

Owns a request for a specific sound when none is on hand. Trigger: "I need a sound
for X" — not a film soundtrack (that is `score`) and not a check of an existing
sound (that is `verify`).

## Read first

`<config>/misc/modules/sound/AGENTS.md` owns the hard gates. Then, in order:
`<config>/misc/modules/sound/rules/acquire/README.md`, the guide root
`<config>/misc/guides/sound/README.md`, and only the bucket READMEs the task
names (`making-sounds/`, `building-sounds/`). Do not load a sibling intent.

## Sequence

1. Phrase the need as a description of the sound, not the job it will do.
2. Try the catalogue design first; read the whole answer, not just the file, and
   act on every warning line.
3. If the design is a stand-in or missing, build from parts; hand a cookbook
   sketch over as a start, never as the thing.
4. Place the hit using the reported peak offset; a separate editor puts it on
   the timeline.
5. Hand the candidate to `verify` for a reading before claiming quality.

## Gates

- A stand-in is never passed off as the requested thing.
- A result other than `clean` is not handed over; remake with another seed.
- No claim about how it sounds before a reading exists.

## Rules applied

`<config>/misc/modules/sound/rules/acquire/README.md` — driven by the
`making-sounds` and `building-sounds` buckets.

## Handoff

- On success → `verify`.
- Sound belongs to a film or motion video → `score`.
- The moment warrants no sound → `place`.
- Missing provider or licence question → `setup`.

## Never

- Describe a sound beyond its descriptions, or call a sketch the finished thing.
- Open a whole bucket of lessons to answer a single request.
