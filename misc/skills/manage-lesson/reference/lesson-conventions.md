# Lesson conventions

A lesson is one standalone, actionable idea in a bucket directory of a guide.

## File shape

```md
# One clear lesson title

**Feeds stage:** <bucket name>

Short, concrete, actionable. Say what to do and why. Add an example or
counterexample when the source gives one. Keep it to one idea.
```

There is intentionally **no `Source:` line and no link to the archived article**. Lessons are orphaned by design: they are read by consumers (for example a design pipeline) without the article, so they must stand on their own. Article URLs and frontmatter belong in `misc/sources/`, not here.

## Buckets

Use the canonical buckets declared in the guide's top-level `README.md`. A bucket may be absent until the first lesson is written. Create a new one only if a lesson fits none of them; create its `README.md` in the same pass and flag the new bucket in the report.

Typical buckets in a web-design guide: `taste/`, `process/`, `typography/`, `color/`, `spacing/`, `layout/`, `hierarchy/`, `backgrounds/`, `motion/`, `copy/`, `mistakes/`, `qa/`, `notes/`.

`notes/` holds asides, not lessons — short versions, terminology and article-specific context.

## One idea per file

- If a lesson needs "and also…", that second idea belongs in its own file (or an existing file that already covers it).
- Prefer concrete rules, diagnostics and checklists over vague philosophy. If the source is philosophical, extract its actionable implication.
- Do not invent lessons the source does not support.

## Enrich, don't duplicate

Before writing, list the target bucket and read anything that could cover the same idea.

- Same idea already present → **edit that file**: sharpen the wording, add the new example/counterexample, add the new nuance. Do not add source links.
- Genuinely distinct idea → new file.
- Two overlapping lessons and neither clearly better → ask the user whether to merge.

## Bucket READMEs

Each bucket has a `README.md` with a one-line description and a bullet list of its lessons. Keep it in sync in the same pass as any write, rename or delete:

```md
# Bucket name

What part of the process this feeds.

- [Lesson title](lesson-file.md)
```
