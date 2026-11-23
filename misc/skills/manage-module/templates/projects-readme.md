# Records

One record per target of the module's work. This folder holds only the shape and
the index convention; actual records live under
`{{RECORDS_PATH}}<stable-slug>/`.

## Slug rules

- Immutable, lowercase kebab-case; human names are fields inside the record.
- Never rename a slug to "clean up" — links break. Add an alias field instead.

## Record shape

Each record has the files its lifecycle needs, for example:

- `BRIEF.md` — what and why
- `DECISIONS.md` — approved choices with their lesson evidence
- `REVIEW.md` — verbatim review notes; never turn it into a second checklist

## Index

`{{WORKSPACE}}PROJECTS.md` is the index: one status, one-line purpose, and the
path only when it overrides the default. It is for discovery, not approval.
