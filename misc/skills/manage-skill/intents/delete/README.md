# Intent: delete

Remove one skill only after an explicit confirmation.

## Read chain

1. [`../../SKILL.md`](../../SKILL.md) — router; this is the chosen intent.
2. [`../rules.md`](../rules.md) — all shared rules apply, including scope
   resolution, canonical paths, and verify/report.
3. This file — adds the reference check, confirmation gate, and link cleanup.
4. The move intent adopts this file's confirmation rule for its source deletion.

## Parameters

- `name` — the skill to remove; ask if missing.
- `scope` — resolve using the rules; inspect the requested scope first.
- `confirm` — explicit user confirmation for this exact canonical path.

## Steps

1. Resolve scope and the exact canonical directory by the rules, including its
   disambiguation.
2. **Reference check:** find the canonical folder and every discovery link or
   reference to it — `AGENTS.md` pointers, symlinks, `.cursor/`/`.claude/`
   adapters, README lists, and references from other skills. Report each with
   its path. Do not follow symlinks into another scope.
3. Present the deletion target (the exact canonical path) and the reference
   list, then ask for explicit confirmation. Stop and wait. **Never delete
   without confirmation** — confirm must come from the user for this specific
   path; do not infer it from the original "remove it" request.
4. After confirmation, remove only the approved canonical folder. Remove the
   discovery links from step 2 that point at it, using `manage-rule` with the
   same scope for `AGENTS.md` changes. Never remove a shared `AGENTS.md` just to
   drop one pointer, and never remove shared dependencies.
5. Verify and report per the rules: path removed, links cleaned up, anything
   intentionally left, and confirmation received.

## Do not

- Delete before confirmation, delete by fuzzy name, follow symlinks into another
  scope, or commit without authorization.
