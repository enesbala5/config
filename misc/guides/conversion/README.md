# Conversion guide

Evidence for the global `conversion` module (to be created). Sources are
verbatim archives of selected conversion skills; lessons are standalone ideas
extracted from them. The module holds rules derived from these lessons, never
copies of them.

## Status

Initialised; sources archived; lesson extraction pending. Buckets were declared
here and are created on demand as their first lesson lands.

## Selected sources

| Slug | Original material | Role | State |
| --- | --- | --- | --- |
| `cro` | `misc/skills/cro/` | Page and form conversion, audits, experiments | archived |
| `emails` | `misc/skills/emails/` | Lifecycle email sequences, copy, templates | archived |
| `onboarding` | `misc/skills/onboarding/` | Post-signup activation, first-run experience, time-to-value | archived |
| `paywalls` | `misc/skills/paywalls/` | Upgrade screens, upsells, in-product monetisation | archived |

These four skills are the initial selection; add a source later by extending
this table and archiving it under `misc/sources/`.

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
| `page-conversion/` | Page and form audits, messaging, friction, CTA and layout fixes | `audit` |
| `activation/` | Post-signup activation, first-run experience, empty states, aha moment | `audit` |
| `monetization/` | Paywalls, upgrade prompts, trials, tier and commitment decisions | `audit` |
| `lifecycle-email/` | Sequence design, email types, copy guidelines, cadence | `plan` |
| `experiments/` | Hypotheses, test design, metrics, iteration, programme cadence | `verify` |
| `mistakes/` | Anti-patterns, unsupported claims, ethical limits, failure modes | `verify` |

These six buckets are the declared set. A future bucket is declared here first
and created only when its first lesson lands. The **Feeds stage** values name
the consuming module's intents or stages; the consuming workspace aligns its
router to these names.

## Pipeline placeholder

Routing from stages to lessons is owned by the consuming workspace, not by this
guide. The `conversion` module's workspace will declare the stage/index that
maps these buckets to its intents once it is initialised.

## Consumers

The global `conversion` module derives its rules from these lessons:
workspace `<config>/misc/modules/conversion/`, router
`<config>/misc/skills/conversion/SKILL.md`, and rules under
`<config>/misc/modules/conversion/rules/`. Rules point here by bucket path;
this guide never reads the module.
