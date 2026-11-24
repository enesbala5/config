# Read the timeline and trust sync only above chance

**Feeds stage:** listening

`earshot timeline film.mp4 --cues cues.json` (or `soundtrack.wav --video film.mp4`) is the listening transcript: events with time, level and tags, sections, loudness curve, picture cuts, sync per cut/cue. `--detail low` is fast; `high` tags up to 96 events, most important first — the summary says how many were tagged, so an untagged event is not a missing sound. Read the sync stats: `offset_ms` is sound minus picture (negative = early), and the 'chance' fraction says what random edit points would score; only better-than-chance sync means anything. A cut listed with no hit can still carry a soft whoosh: check it on the sheet before adding a sound. Measured: 93 % of the sound effects in a 60 s film mix are found as events (89 % of the quiet ones under music); a 60 to 90 s film takes about 1.5 minutes on a laptop CPU.
