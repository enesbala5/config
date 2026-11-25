# Stage: cue

Owns the cue list and the sync frames derived from the picture.

## Route

Guide buckets: `film-sound`. Load `<config>/misc/guides/sound/README.md`, the
`film-sound` bucket README, then only the lessons the task names.

## Adds / overrides

Frames come from the picture's computed cuts; animation cues are supplied
explicitly because motion inside a shot is not an event.

## Done when

The cue list exists and every cue carries a computed sync frame.
