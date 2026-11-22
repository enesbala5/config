# Intent: extract-from-guide

Turn one archived article into lessons. Run once per article; for several articles, run this intent sequentially with a handoff between agents.

## Parameters

- `topic`, `dir` — common parameters.
- `source` — optional slug or path to the archived article. **If missing, print the pending sources and ask which one to process** (or take the `next_input.source` from a handoff). Never pick silently.

## Steps

1. Read the guide's top-level `README.md` for canonical buckets and conventions, then read the **entire** article in `<dir>/misc/sources/`.
2. Before writing, list files in each candidate bucket and **read any existing lesson that covers the same idea**. This is the enrich-not-duplicate step and it is mandatory.
3. Extract lessons — one idea per file. Use the template in [`../templates/lesson.md`](../templates/lesson.md). Rules:
   - title, `**Feeds stage:** <bucket>`, short concrete body, example/counterexample when the article gives one;
   - **no `Source:` line, no link back to the article** — lessons are standalone;
   - prefer concrete rules, checklists and diagnostics over vague philosophy; do not invent lessons the article does not support.
4. If an idea already exists, **enrich that file**: sharpen the wording, add the new example/counterexample. Do not create a second file. Do not add source links while enriching either.
5. Put each lesson in a canonical bucket. Create a new bucket (directory + `README.md`) only if nothing fits, and flag it in the report.
6. Update every touched bucket's `README.md` bullet list so it includes all files actually in the bucket, including enriched ones.
7. Run `node <skill>/scripts/verify-lessons.js <dir>` and fix any problems.

## Output

Emit a handoff with `intent: extract-from-guide`, `status: ready`, the source slug marked processed, files created/enriched grouped by bucket, and `next_intent` set to the next pending source (or `manage-lesson / audit` if this was the last one).

## Do not

- Process more than one article per invocation.
- Modify the archived source, the top-level guide README, or anything outside `<dir>`.
- Commit.
