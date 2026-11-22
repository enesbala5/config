# Intent: audit

Read-only review of the lesson layer.

## Parameters

- `topic`, `dir` — common parameters.
- `scope` — optional bucket name or `all` (default `all`).
- `fix` — boolean, default false. When false, report only.

## Steps

1. Run `node <skill>/scripts/verify-lessons.js <dir>` for structural checks: title, `**Feeds stage:**`, bucket README coverage, dead README bullets.
2. Check semantic overlap: for each bucket, compare lesson titles and first paragraphs; flag pairs that appear to state the same idea. Also check across buckets where ideas commonly drift (`mistakes/` vs `process/`, `hierarchy/` vs `layout/`, `taste/` vs `notes/`).
3. Flag lessons that are too thin to act on, lessons that bundle several ideas, and any accidental `Source:` lines or article links.
4. Report grouped by bucket with exact file paths. If `fix: true`, only apply changes the user has already approved; otherwise stop and ask which to apply.

## Do not

- Merge or delete lessons without confirmation, even with `fix: true`.
- Report structural "problems" that are intentional (lessons are orphaned by design).
