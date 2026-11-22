---
name: manage-lesson
description: Maintain the lesson layer of an evidence-backed guide. Use for extract-from-guide (turn one archived article into one-idea files in topic buckets, enriching rather than duplicating), delete, enrich, and audit. Triggers include "extract learnings from this article", "add this insight to the lessons", "remove this lesson", "audit the lesson buckets".
---

# Manage lessons

A lesson is a single, standalone idea in a bucket directory of a guide. Lessons do **not** carry a link back to the source article — they are intentionally orphaned so they can be read and reused without the article. This skill owns the **lessons**; the guide folder and its sources belong to `manage-guide`.

Run **one intent at a time**. If the user's request is ambiguous, list the intents and ask.

## Common parameters

| Parameter | Meaning | Resolution |
|---|---|---|
| `topic` | Short subject name | If missing, **ask the user** — never guess |
| `dir` | Repository-relative guide directory | Explicit value wins; otherwise derive `<repo>/misc/guides/<topic-slug>/`; ask if it cannot be derived |

Each intent adds its own parameters. **If a required parameter is missing, prompt interactively before changing anything** — list the available sources or lessons so the user can pick by number or slug.

Resolve the repository root with `git rev-parse --show-toplevel`. Read `AGENTS.md`, the guide's top-level `README.md`, the target bucket `README.md` and any existing lesson that might overlap before writing. Preserve unrelated changes; never commit unless asked.

## Intents

| Intent | Extra parameters | Result |
|---|---|---|
| [`extract-from-guide`](intents/extract-from-guide.md) | `source` (slug/path; default: next pending source) | One-idea lesson files in canonical buckets; existing lessons enriched instead of duplicated; bucket READMEs updated |
| [`delete`](intents/delete.md) | `lesson` (slug/path), `confirm` | Removes a lesson after reference check and confirmation; fixes the bucket README |
| [`enrich`](intents/enrich.md) | `lesson`, `with` | Adds a new example, counterexample or nuance to an existing lesson without creating a duplicate |
| [`audit`](intents/audit.md) | `scope` (bucket or whole guide), `fix` (default false) | Read-only report of overlapping lessons, unindexed files, missing structure |

## Rules that apply to every intent

Full conventions: [`reference/lesson-conventions.md`](reference/lesson-conventions.md).

- One idea per file. Small, concrete, actionable; an example or counterexample when one exists.
- Use the canonical buckets in the guide README. Create a new bucket only when a lesson fits none, and add its `README.md` in the same pass.
- **Enrich, don't duplicate.** If an existing lesson covers the idea, edit that file instead of creating a second one.
- A lesson file has a title, a `**Feeds stage:**` line and the body. **No `Source:` line and no source-article links.**
- Update the touched bucket's `README.md` bullet list in the same pass.

## Sequential extraction and handoffs

When processing several articles, run one `extract-from-guide` invocation per article, one after another, passing the previous agent's handoff to the next. See [`reference/workflow.md`](reference/workflow.md) for the exact subagent prompt and [`reference/handoff.md`](reference/handoff.md) for the handoff block. Each agent must read the current buckets before writing, which is what makes enrich-not-duplicate work across agents.

## Verification

Run `node scripts/verify-lessons.js <dir>` after any write. It checks title/`Feeds stage:` presence, that every lesson is listed in its bucket README, and that README bullets resolve to real files. Report files created and enriched, grouped by bucket.

## Failure handling

- If two lessons seem to overlap and neither is clearly better, ask the user whether to merge before editing.
- If a source article is missing or empty, stop and report; do not invent lessons.
- Deletion without explicit confirmation is never allowed; show the reference check first.
