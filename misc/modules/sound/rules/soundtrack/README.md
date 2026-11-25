# Rules: soundtrack

Pipeline gates, licence policy and tool contracts for real-recordings soundtracks.
Driven by the `film-sound` and `tooling-and-providers` buckets.

- Every named step hands a concrete artifact and passes its gate; no step is
  skipped to reach the film faster.
  Evidence: `<config>/misc/guides/sound/film-sound/ten-steps-with-owners-and-gates.md`
- Sound events land on frames computed from the picture, not guessed from cuts.
  Evidence: `<config>/misc/guides/sound/film-sound/every-sound-on-a-computed-cue-frame.md`
- The mix is a deterministic render of the design; QA findings trace to the rule
  and sample that caused them.
  Evidence: `<config>/misc/guides/sound/film-sound/deterministic-mix-and-traced-qa.md`
- Critics stay read-only; one fixer merges their operations and requires no QA
  regression before applying them.
  Evidence: `<config>/misc/guides/sound/film-sound/five-read-only-critics-one-fixer.md`
- Master acceptance is measured: -14 LUFS within ±0.5 LU, ≤ -1.5 dBTP, and
  ≤ -1 dBTP after codec encoding.
  Evidence: `<config>/misc/guides/sound/film-sound/master-gate-lufs-and-true-peak.md`
- A film closes only with a clean audit, credits and a mux at zero lag.
  Evidence: `<config>/misc/guides/sound/film-sound/credits-and-mux-close-the-film.md`
- Licence classification is explicit: unverified blocks; audit exits 0 for
  exactly what the film uses; attribution is carried into credits and description.
  Evidence: `<config>/misc/guides/sound/tooling-and-providers/licence-policy-allowed-forbidden-unverified.md`
- Licence, provenance and attribution need a separate source of truth; the audio
  provider cannot judge them.
  Evidence: `<config>/misc/guides/sound/tooling-and-providers/licence-and-provenance-are-not-audio-questions.md`
- Models judge and do not generate; when a check could not run, say what was not
  heard instead of implying validation.
  Evidence: `<config>/misc/guides/sound/tooling-and-providers/models-judge-not-generate.md`
- Install from the pinned GitHub source and check with `doctor`; offline work
  uses pinned models from a local cache.
  Evidence: `<config>/misc/guides/sound/tooling-and-providers/install-and-doctor.md`,
  `<config>/misc/guides/sound/tooling-and-providers/offline-and-pinned-models.md`
- `real-sound` runs as scripts on one interpreter with `-I`; the licence policy
  module is imported rather than invoked as a script.
  Evidence: `<config>/misc/guides/sound/tooling-and-providers/real-sound-is-a-script-driven-provider.md`
