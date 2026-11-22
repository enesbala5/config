# Intent: enrich

Improve one existing lesson with a new insight, without creating a duplicate.

## Parameters

- `topic`, `dir` — common parameters.
- `lesson` — required slug/path. **If missing, list lessons in the likely bucket and ask.**
- `with` — required: the new example, counterexample, nuance or correction. If the user gives only a URL or an article, read it first and summarize the specific addition, then confirm before editing.

## Steps

1. Read the target lesson and its sibling lessons in the same bucket to avoid drift or overlap.
2. Add only the new material: a sharper phrasing, one concrete example/counterexample, or a correction. Keep the file to one idea and keep it short.
3. Do not add a `Source:` line or any source-article link; lessons stay standalone.
4. Update the bucket README only if the lesson's title changed.
5. Run `node <skill>/scripts/verify-lessons.js <dir>`.

## Do not

- Turn the lesson into a summary of a whole article.
- Create a new file when the existing one can absorb the insight.
