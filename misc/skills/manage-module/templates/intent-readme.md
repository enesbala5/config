# Intent: {{INTENT}}

_{{One line: which requests this intent owns, and the one-line trigger that
distinguishes it from its siblings.}_

## Read first

`{{WORKSPACE}}AGENTS.md` owns the hard gates. `_Name any index or rule file
this intent needs, in read order. Do not load a whole bucket or a sibling
intent._

## Sequence

1. _{{Step...}}_
2. _{{Step...}}_
3. _{{Step...}}_

## Gates

- _{{What must be true before changing anything.}}_
- _{{What must be approved, by whom.}}_

## Rules applied

_{{Name the rules by path and the guide buckets they come from. Do not paste
lesson text here.}_

## Handoff

- On success → _{{next intent or "done"}}_
- On failure or out of scope → _{{where to hand back}}_

## Never

- _{{Intent-specific prohibition, e.g. "edit in a read-only intent".}}_
