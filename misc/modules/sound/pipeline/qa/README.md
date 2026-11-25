# Stage: qa

Owns measured QA and the listening transcript.

## Route

Guide buckets: `listening`, `film-sound`. Load `<config>/misc/guides/sound/README.md`,
the named bucket READMEs, then only the lessons the task names.

## Adds / overrides

Findings are tied to the rule and sample through the trace; model-free QA and
model-assisted listening are separate passes, and neither replaces a measurement.

## Done when

A QA report exists with no failing finding.
