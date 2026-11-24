# The mix is deterministic and QA is measured and traced

**Feeds stage:** film-sound

The soundtrack is a render of the design JSON: the mixer deterministically trims, places, levels, pans, EQs and time-stretches recordings, so there is no performance to listen for. `qa.py` measures clicks, edges, audibility, harshness, loudness, coverage, sync and density, and ties every finding to the rule and sample that caused it through the trace (`mix.py --trace` writes it). A finding is therefore actionable: go to the named rule and sample, not a vague "sounds off". `--layers` runs model-free QA; `--listen` adds earshot's transcript, annotated sheet and scorecard. Verify a fragment alone before integrating it with `--only <cat>`, `--dump` (every trim as WAV plus numbers), a solo render and `earshot timeline`.
