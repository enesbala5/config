# Intent: verify

Check guide and archive integrity. Read-only.

## Parameters

- `topic`, `dir` — common parameters.

## Steps

1. Run `node <skill>/scripts/verify-guide.js <dir>`. It checks:
   - frontmatter keys and non-empty values on every archived source,
   - that each source file's `source` URL is present,
   - that the sources README lists every archived file,
   - that no archive file is suspiciously short.
2. Report problems grouped by file. Do not auto-fix unless the user asks.
3. Emit a handoff with the problem list and `next_intent` — `save-online-source` for archive problems, `manage-lesson / audit` for lesson-level problems.

## Do not

- Modify files or skip checks because "it looked fine last time".
