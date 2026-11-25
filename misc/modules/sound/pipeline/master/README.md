# Stage: master

Owns the loudness gate, credits and the mux.

## Route

Guide buckets: `film-sound`, `tooling-and-providers`. Load
`<config>/misc/guides/sound/README.md`, the named bucket READMEs, then only the
lessons the task names.

## Adds / overrides

Acceptance is measured, not judged by a listen: -14 LUFS within ±0.5 LU,
≤ -1.5 dBTP, and ≤ -1 dBTP after codec encoding. Credits must exit 0 and the mux
must report zero lag.

## Done when

The master is inside the gate, credits are clean, and the mux has closed the film.
