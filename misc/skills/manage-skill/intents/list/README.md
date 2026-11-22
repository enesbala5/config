# Intent: list

Report skills and their scopes. Read-only.

## Read chain

1. [`../../SKILL.md`](../../SKILL.md) — router; this is the chosen intent.
2. [`../rules.md`](../rules.md) — scope resolution and canonical paths apply.
3. This file — adds only the list-specific reporting shape.

## Parameters

- `scope` — optional; global, local, or both. Resolve with the rules.
- `name` — optional filter. If a name exists in both scopes and the user has not
  identified one, report both copies rather than guessing.

## Steps

1. Inspect the requested scope first as the rules require, and resolve each
   canonical path there.
2. For each skill found, report its name, description (purpose and triggers),
   canonical path, and scope. Distinguish local and global copies explicitly.
3. Note discovery symlinks or pointers as adapters, not additional canonical
   copies.
4. Emit the short report from the rules. No files change.

## Do not

- Modify files, infer a name when scope is ambiguous, or follow symlinks into
  another scope while listing.
