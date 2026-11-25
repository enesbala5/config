# Stage index

Routing only — no lesson content lives here. Lessons stay in `<config>/misc/guides/sound/`.

An intent names a stage; the reader loads this file, the stage README, the guide
root README, the bucket README, then only the lessons the task names. Never read
a whole bucket, and never open a second sibling branch for the same question.
A nested stage file only adds or overrides; it never restates an ancestor.

| Stage | Owns | Guide buckets |
| --- | --- | --- |
| cue | Cue list and picture-derived sync frames | film-sound |
| brief | Sound need for each cue, or an explicit "nothing" | placement-and-limits, film-sound |
| source | Per-category assets and manifest, measured and realness-checked on the trim used | tooling-and-providers, listening |
| audit | Licence classification and attribution | tooling-and-providers |
| music | Music edit against the picture | film-sound |
| design | Per-category sound fragments and their solo checks | making-sounds, building-sounds |
| integrate | Deterministic render into soundtrack, stems and trace | film-sound |
| qa | Measured QA plus listening transcript | listening, film-sound |
| critique | Five read-only critic lenses proposing variants | listening, film-sound |
| fix | One fixer merging and applying critic operations | film-sound |
| master | Loudness gate, credits and mux | film-sound, tooling-and-providers |

## Adding to the pipeline

- A new lesson goes into a guide bucket first; the bucket README is its index.
  No edit here unless a *whole bucket* is new.
- A new stage is one folder here plus one row in the table above. Intent files
  keep pointing at this index, not at individual lessons.
