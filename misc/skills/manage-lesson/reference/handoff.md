# Handoff contract (lesson side)

Use the exact same block shape as `manage-guide/reference/handoff.md` so a chain can cross between skills.

```text
HANDOFF
skill: manage-lesson
intent: extract-from-guide | delete | enrich | audit
status: ready | awaiting_user | blocked | done
topic: <subject>
dir: <repo-relative guide directory>
params:
  source: <slug of article just processed>
artifacts:
  - <bucket>/<new-file>.md
  - <bucket>/<enriched-file>.md (enriched)
  - <bucket>/README.md (updated)
next_intent: manage-lesson / extract-from-guide | manage-lesson / audit | none
next_input:
  source: <slug of next pending article>   # omit when none remain
open_questions:
  - <question>            # omit when none
notes: <one line of context>
```

## Rules

- Always report enriched files explicitly with `(enriched)` so the next agent knows they already exist.
- `status: awaiting_user` is used by `delete` (reference check confirmation) and `enrich` (when the addition needs approval).
- `blocked` names the reason in `notes` — for example a missing or empty source article.
- When no articles remain, set `next_intent: manage-lesson / audit` and omit `next_input.source`.
- Keep it compact; this block is the next agent's prompt input.
