# Lesson extraction workflow

This is the extraction half of the full workflow documented in the `manage-guide` skill (`reference/workflow.md`). It is invoked once per archived article, sequentially.

## Why sequential

Each agent must see the buckets as earlier agents left them. Sequential execution is what makes the enrich-not-duplicate rule work across agents. Do not parallelize `extract-from-guide` invocations for the same guide.

## Preconditions

- The article exists in `<dir>/misc/sources/` and has been verified by `manage-guide / verify`.
- The guide's top-level `README.md` declares the canonical buckets and conventions.
- The caller supplied `source` (slug/path) or a handoff with `next_input.source`.

## One invocation

1. Read the guide README and the **whole** source article.
2. Read existing lessons in every candidate bucket; note which ideas are already covered.
3. Draft the lesson list. Group by bucket. Mark each item `new` or `enrich <existing-file>`.
4. Write new files from the [template](../templates/lesson.md) and apply enrichments. No `Source:` lines.
5. Update each touched bucket `README.md`.
6. Run `node <skill>/scripts/verify-lessons.js <dir>`.
7. Return a [handoff](handoff.md) with `status: ready`, the processed source slug, files created/enriched, and `next_intent`: the next pending source, or `manage-lesson / audit` when none remain.

## Launching the next agent

```
You are executing `manage-lesson / extract-from-guide` from the global skill of the same name.
Read that skill's SKILL.md and intents/extract-from-guide.md fully before acting.
Inputs:
<paste HANDOFF block, with next_input.source changed to the next article>
Work only inside <dir>. Do not commit.
Return a HANDOFF block when done.
```

## After the last article

Run `manage-lesson / audit` for overlap and structural checks. Do not run a separate "finalize" step: routing from stages to lessons is owned by the consuming workspace (`misc/design/pipeline/` in Coverlttr), not by the guide.
