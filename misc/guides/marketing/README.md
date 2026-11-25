# Marketing guide

Evidence for the global `marketing` module. Sources are verbatim archives of
selected marketing skills and other material; lessons are standalone ideas
extracted from them. The module holds rules derived from these lessons, never
copies of them.

## Status

Eleven sources archived verbatim. The original ten yielded 157 audited lessons
across eight buckets. The social media marketing transcript is pending extraction.
Buckets were created on demand as their first lesson landed.

## Selected sources

| Slug | Original material | Role | State |
| --- | --- | --- | --- |
| `customer-research` | `misc/skills/customer-research/` | Audience, VOC, ICP, JTBD | archived |
| `marketing-council` | `misc/skills/marketing-council/` | Competing frameworks, trade-offs | archived |
| `marketing-ideas` | `misc/skills/marketing-ideas/` | Idea selection by stage and resources | archived |
| `marketing-psychology` | `misc/skills/marketing-psychology/` | Mental models, ethical influence | archived |
| `offers` | `misc/skills/offers/` | Offer construction, risk reversal | archived |
| `launch` | `misc/skills/launch/` | Go-to-market sequencing | archived |
| `ab-testing` | `misc/skills/ab-testing/` | Hypotheses, experiments, programme | archived |
| `marketing-campaign` | `misc/skills/marketing-campaign/` | Campaign orchestration | archived |
| `community-marketing` | `misc/skills/community-marketing/` | Community-led growth | archived |
| `lead-magnets` | `misc/skills/lead-magnets/` | Capture offers and distribution | archived |
| `the-new-era-of-social-media-marketing` | User-supplied talk transcript | Social strategy, creator distribution, creative testing | archived; extraction pending |

Deliberately out of scope: `free-tools`, `onboarding`, `cro`, the OpenSEO set,
and content-production skills (`ad-creative`, `cold-email`, `emails`, `social`,
`paywalls`, `popups`, `react-email`, `voice`, `zernio-social-posting`). Content
execution belongs to the `copy` module; visual execution to the `design`
module. Add a source later by extending this table and archiving it.

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
| `research/` | Audience and problem discovery, VOC, pain points, competitive and demand inputs | `research` |
| `positioning/` | Problem ownership, audience priority, category, differentiation, messaging hierarchy, claims boundaries | `position` |
| `offers/` | Offer construction, packaging, guarantees, risk reversal | `plan` |
| `channels/` | Channel selection, community, lead magnets, growth loops, channel role | `plan` |
| `launch/` | GTM sequencing, campaign roles, phased plans | `plan` |
| `experiments/` | Hypotheses, test design, metrics, iteration, programme cadence | `verify` |
| `handoffs/` | Strategy → copy and strategy → design boundaries, approval gates, what strategy does not produce | `handoff` |
| `mistakes/` | Anti-patterns, unsupported claims, ethical limits, failure modes | `verify` |

All eight buckets are in use. A future bucket is declared here first and created
only when its first lesson lands. The **Feeds stage** values name the consuming
module's intents or stages; the consuming workspace aligns its router to these
names.

## Pipeline placeholder

Routing from stages to lessons is owned by the consuming workspace, not by this
guide. The `marketing` module's workspace declares the stage/index that maps
these buckets to its intents once it is initialised.

## Consumers

The global `marketing` module derives its rules from these lessons: workspace
`misc/modules/marketing/`, router `misc/skills/marketing/SKILL.md`. Rules point
here by bucket path; this guide never reads the module.
