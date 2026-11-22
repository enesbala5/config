# Intent: move

Move one skill from its current canonical folder to another scope or repository:
global ↔ local, or local ↔ local. A move is a copy plus deletion of the source;
the confirmation gate from [`../delete/README.md`](../delete/README.md) applies
to the source path.

## Read chain

1. [`../../SKILL.md`](../../SKILL.md) — router; this is the chosen intent.
2. [`../rules.md`](../rules.md) — all shared rules apply to both repos and
   scopes: scope resolution, canonical paths, portable shape, portability gate,
   verify/report.
3. This file — adds the move sequence and path rewriting.
4. [`../delete/README.md`](../delete/README.md) — load only for the source
   confirmation rule and reference check; do not restate them here.

## Parameters

- `name` — the skill to move; ask if missing.
- `from`, `to` — source and destination scope/repository. Resolve both with the
  rules; ask when either is missing or ambiguous.
- `confirm` — explicit user confirmation for deleting the source path.

## Steps

1. Resolve the source scope and destination scope with the rules, performing
   the rules' repo inspection and disambiguation for each side.
2. Run the reference check from the delete intent against the source: locate the
   canonical folder and every link or reference to it in both repos and the
   global config, and list them with paths.
3. Present the exact source → destination canonical paths plus that reference
   list. Ask for explicit confirmation to delete the source and **stop until it
   is given**. Never delete or move the source without it.
4. Move the canonical folder (use `git mv` when tracked in one repo; otherwise
   copy to the destination, verify, then remove the source). Keep one canonical
   copy; add a discovery symlink or pointer only when needed (rules).
5. Rewrite path-dependent instructions in the moved copy so they hold at the
   destination: repository-relative paths that changed, machine-specific
   absolute paths → repository-relative or skill-relative paths, and any
   prerequisites or config locations that differ between repos. Do not change
   behavior beyond path portability.
   - Worked case — `send-coverlttr-email`: its current global copy is at
     `misc/skills/send-coverlttr-email/` in the config checkout. Moving it local
     to the coverlttr repo puts it at
     `<coverlttr>/.agents/skills/send-coverlttr-email/`. Rewrite the
     `misc/emails/emails/founding-member-offer.tsx` template path and the
     absolute audience-file path into paths relative to the coverlttr repo (or
     a documented configuration value). Keep the endpoint, the
     `INTERNAL_JOBS_SECRET` name, the idempotency rules, and the "never print the
     secret" rule unchanged.
6. Update all references in both repos (and the global config when applicable):
   remove discovery pointers/symlinks and references at the source, add them at
   the destination via `manage-rule` with the appropriate scope, and fix README
   lists or other skills' references. Do not delete shared rules or a whole
   `AGENTS.md` to drop one pointer.
7. Apply the portability gate from the rules to the moved copy.
8. **Verify both repos:** for each, check `git status` shows only approved
   changes, the canonical folder exists only at the destination, the source is
   gone, no link is dangling, YAML is valid, and `name` matches the folder. For
   a router/intent change to this skill, end with
   `node <skill>/scripts/verify-skill-router.js`.
9. Verify and report per the rules: source/destination scopes and paths, lines
   rewritten, references updated in each repo, confirmation received, and
   anything unverified.

## Do not

- Delete the source before confirmation, leave two canonical copies, follow
   symlinks into another scope, or commit/push/PR without authorization.
