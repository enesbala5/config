# Intent: create

Create or install one skill at the canonical path for the resolved scope.

## Read chain

1. [`../../SKILL.md`](../../SKILL.md) — router; this is the chosen intent.
2. [`../rules.md`](../rules.md) — all shared rules apply here: scope resolution,
   canonical destination, portable shape, portability gate, verify/report,
   acceptance cases.
3. This file — adds only the create-specific sequence. It does not restate an
   ancestor.

## Parameters

- `name` — lowercase kebab-case; required. Ask if missing; validate against
  `[a-z0-9]+(-[a-z0-9]+)*` (rules).
- `scope` — global or local; resolve using the rules, asking only when missing
  or ambiguous.
- `source` — optional path to an existing skill to import; the portability gate
  applies to imports.
- `router` — optional full router markdown handed over by `manage-module`; write
  it verbatim rather than reading that skill's workspace.

## Steps

1. Inspect the target repo's `AGENTS.md`, conventions, and `git status --short`;
   resolve both repos as needed per the rules. Preserve unrelated changes.
2. Resolve scope by the rules, including its disambiguation and the questions
   the request already answers.
3. Resolve the canonical destination by the rules, including its symlink and
   checkout verification, overwrite checks, and name validation.
4. Write `<canonical>/SKILL.md` plus supporting files beside it, using the
   portable skill shape from the rules. For a handed-off router, write the
   quoted router verbatim and keep `name` equal to the folder name.
5. Apply the portability gate from the rules to the new skill and to any imported
   skill, including its import adaptation and incompatibility reporting.
6. If the skill needs an always-on project rule, use `manage-rule` with the same
   scope (rules) and keep the rule discoverable through `AGENTS.md`.
7. Verify and report per the rules. For a router/intent change to this skill,
   end with `node <skill>/scripts/verify-skill-router.js`.

## Do not

- Ask for scope the user already gave; do not install globally for a local
  request (acceptance cases).
- Duplicate the implementation into a second location or leave an installed
  copy as the only source.
- Commit, push, or publish without authorization.
