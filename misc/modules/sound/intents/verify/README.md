# Intent: verify

Read-only evidence check on a sound, take, trim, mix or decision. Trigger: "is
this right / real / loud enough / does it fit" — any request that would produce
a claim about audio.

## Read first

`<config>/misc/modules/sound/AGENTS.md` owns the hard gates. Then, in order:
`<config>/misc/modules/sound/rules/evidence/README.md`, the guide root
`<config>/misc/guides/sound/README.md`, and the named buckets `listening/` and
`placement-and-limits/`. Do not load a sibling intent.

## Sequence

1. Run the relevant earshot reading — measure, realness, match/rank/find, A/B,
   timeline or critique — on the exact trim that will be used.
2. Read exact measurements first, then verdicts and `z`; never present raw
   similarity as confidence.
3. Judge a made sound against the references, not only the model score; a
   high score can mean the critic is satisfied rather than the sound improved.
4. Report the numbers and name plainly what was not checked or cannot be judged.

## Gates

- This intent never edits an artifact; it reports and hands fixes to `make` or `score`.
- No quality or fit claim without a quoted reading.
- Upload critique runs only after explicit per-call user consent.

## Rules applied

`<config>/misc/modules/sound/rules/evidence/README.md` — driven by the
`listening` and `placement-and-limits` buckets.

## Handoff

- Finding to fix → `make` for a single sound, `score` for a soundtrack.
- Clean and fully stated → done.
- Provider unavailable or unverified licence → `setup`.

## Never

- Pass upload consent on your own, or present a model score as proof of a person's judgement.
- Edit files, apply fixes, or open a second bucket for the same question.
