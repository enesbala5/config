# Social guide

Evidence for the global `social` module (to be created). Sources are verbatim
archives of selected social skills; lessons are standalone ideas extracted from
them. The module holds rules derived from these lessons, never copies of them.

## Status

Initialised; source archived; 30 lessons extracted across all six declared
buckets and audited. Buckets were declared here and are created on demand as
their first lesson lands.

## Selected sources

| Slug | Original material | Role | State |
| --- | --- | --- | --- |
| `social-metadata-hardening` | `misc/skills/social-metadata-hardening/` | Rich link previews: OG/Twitter tags, absolute image URLs, platform caches | archived |

Add a source later by extending this table and archiving it under `misc/sources/`.

## Lesson conventions

- One idea per file, in one of the canonical buckets below.
- A lesson has a title, a `**Feeds stage:** <stage>` line, and a short, concrete,
  actionable body with an example or counterexample when the source gives one.
- No `Source:` line and no link back to the archive: lessons are orphaned by
  design so they can be read without the article.
- Enrich an existing lesson rather than duplicating it; update the bucket
  README in the same pass as any write.
- A bucket directory is created only when its first lesson is written. The
  declared buckets are the known places to put a future lesson; they are not
  empty scaffold to maintain.

## Buckets

| Bucket | Holds | Feeds stage |
| --- | --- | --- |
| `sharing-metadata/` | OG and Twitter card tags, canonical URLs, `metadataBase`, crawlable static tags | `audit` |
| `og-images/` | Image dimensions, MIME types, HTTPS, file naming and accessibility | `build` |
| `platform-behavior/` | Which tags each platform respects, cache lifetime and recrawl tools | `audit` |
| `debugging/` | Raw-HTML checks, validators and forced cache refresh | `verify` |
| `mistakes/` | Anti-patterns, stale previews, unsupported claims and limitations | `verify` |
| `qa/` | Pre-launch checklists for shareable pages | `verify` |

These six buckets are the declared set. A future bucket is declared here first
and created only when its first lesson lands. The **Feeds stage** values name
the consuming module's intents or stages; the consuming workspace aligns its
router to these names.

## Pipeline placeholder

Routing from stages to lessons is owned by the consuming workspace, not by this
guide. The `social` module's workspace will declare the stage/index that maps
these buckets to its intents once it is initialised.

## Consumers

The global `social` skill (`<config>/misc/skills/social/SKILL.md`) is the current
consumer; a future social module workspace will derive its rules from these
lessons. Rules point here by bucket path; this guide never reads the module.
