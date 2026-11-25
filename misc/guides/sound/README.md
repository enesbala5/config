# Sound guide

Evidence for the future global `sound` module. Sources are verbatim archives of
the earshot agent SKILL.md, the earshot README.md and the companion `real-sound`
SKILL.md (from the Leonxlnx/earshot GitHub repo); lessons are standalone ideas
extracted from them. The module holds rules derived from these lessons, never
copies of them.

## Status

Sources archived and verified. 57 lessons extracted across six buckets and audited (no structural problems; a short overlap watchlist is recorded in the audit). The future `sound` module derives its rules from these lessons.

## Sources

| Slug | Original | Status |
| --- | --- | --- |
| `earshot-skill` | `https://raw.githubusercontent.com/Leonxlnx/earshot/main/skills/earshot/SKILL.md` | archived |
| `earshot-readme` | `https://raw.githubusercontent.com/Leonxlnx/earshot/main/README.md` | archived |
| `real-sound-skill` | `https://raw.githubusercontent.com/Leonxlnx/earshot/main/skills/real-sound/SKILL.md` | archived |

Archives will live in [misc/sources/README.md](misc/sources/README.md). No source
is edited or deleted while the guide is in use.

## Lesson conventions

- One idea per file, in one of the canonical buckets below.
- A lesson has a title, a `**Feeds stage:** <bucket>` line, and a short, concrete,
  actionable body with an example or counterexample when the source gives one.
- No `Source:` line and no link back to the archive: lessons are standalone by
  design so they can be read without the source.
- Enrich an existing lesson rather than duplicating it; update the bucket README
  in the same pass as any write.

## Buckets

- `making-sounds/` — requests, sets, files/formats, takes, reading the answer, length/level/peak.
- `building-sounds/` — build from parts, recipes, cookbook, layer controls.
- `listening/` — describe/match/rank/find/ab/realness/timeline/critique/measure, query writing, reading numbers, goodhart.
- `film-sound/` — motion-video scoring, real-footage scenes, kits, bank, forge, fit.
- `placement-and-limits/` — when a sound belongs vs silence, restraint, taste, limits, honesty about what the tooling cannot judge.
- `tooling-and-providers/` — CLI/MCP/Python/plugin setup, licence/provenance/verification, and providers for the future module.

**Feeds stage** lines name the consuming intent in the future `sound` module.
Bucket directories are created by lesson extraction, not at initialisation.

## Consumers

The global `sound` module derives its rules from these lessons:
workspace `misc/modules/sound/`, router `misc/skills/sound/SKILL.md`. Rules point
here by bucket path; this guide never reads the module.
