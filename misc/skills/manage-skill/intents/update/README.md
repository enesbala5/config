# Intent: update

Change one existing skill in place at its canonical path.

## Read chain

1. [`../../SKILL.md`](../../SKILL.md) — router; this is the chosen intent.
2. [`../rules.md`](../rules.md) — all shared rules apply here, including scope
   resolution, canonical paths, the portability gate, and verify/report.
3. This file — adds only the update-specific sequence. It does not restate an
   ancestor.

## Parameters

- `name` — the skill to change; ask if missing.
- `scope` — resolve using the rules; inspect the requested scope first.
- `change` — what to modify (frontmatter, instructions, supporting files).
- `source` — optional path to replacement content; gate it like an import.

## Steps

1. Resolve scope with the rules, including its disambiguation, before reading
   or writing either copy.
2. Read the existing `SKILL.md` and its supporting files. Preserve unrelated
   changes and inspect symlinks before writing (rules).
3. Apply only the requested change. Keep `name` equal to the folder name and the
   `description` accurate about purpose and triggers.
4. Reapply the full portability gate from the rules to the edited skill and
   report any unresolved incompatibility as the rules require.
5. When paths or triggers change, update references and discovery pointers in
   `AGENTS.md` through `manage-rule` with the same scope (rules).
6. Verify and report per the rules. For a router/intent change to this skill,
   end with `node <skill>/scripts/verify-skill-router.js`.

## Do not

- Edit a copy instead of the canonical source, or change an unrelated skill.
- Claim full portability based only on valid frontmatter.
- Commit or publish without authorization.
