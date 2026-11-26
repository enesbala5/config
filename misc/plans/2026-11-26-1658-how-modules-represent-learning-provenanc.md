# Plan: Make the consumption log a standard module file

- Status: complete
- Created: 2026-11-26T16:34:40.756Z
- Project: `/home/e/config`

## Steps

- [x] 1. Make the consumption log a standard module file
- [x] 2. Teach initialize to create it
- [x] 3. Teach extend to maintain it
- [x] 4. Include it in verification
- [x] 5. Module anatomy and generated documentation

## Plan

Plan:

1. **Make the consumption log a standard module file** — Add a YAML template for a module-local `CONSUMED-LESSONS.yml`, with entries containing the lesson’s repository-relative path and the date it was consumed. This records actual module usage without changing guide lessons or conflating usage with verified findings. **Risk:** a date and path alone records consumption, not what changed; adding outcome notes can be considered later.

2. **Teach `initialize` to create it** — Update the manage-module initialization instructions and scaffolder to include the file in new module workspaces, for both local and global scope. For global modules, the file belongs in the workspace with the other shared module definition files; it should log lesson consumption by the module, not per-project activity. **Risk:** existing modules will not gain the file automatically unless separately initialized or updated.

3. **Teach `extend` to maintain it** — Update the manage-module guidance so when a module consumes a lesson while being created or updated, it appends an entry with the lesson path and consumption date. Define repeat consumption as a new dated entry, preserving history rather than overwriting an earlier event. **Risk:** “consumed” should mean the lesson materially informed a module change, not merely that someone opened or considered it.

4. **Include it in verification** — Update manage-module verification to check that the file exists and entries have the expected fields and valid dates/paths. **Risk:** the current verifier handles Markdown checks; YAML parsing may require a dependency or a small focused parser/validation strategy. Avoid adding a dependency unless necessary.

5. **Update the module anatomy and generated documentation** — Document the file as part of the standard module structure and clarify its distinction from `LEARNINGS.md`: the former is a parseable usage log; the latter captures findings from real work. Adjust generated workspace documentation to point to the log. **Risk:** this changes the standard for newly scaffolded modules, not necessarily existing module folders.

**Likely files to modify:**
- `misc/skills/manage-module/templates/` — add the consumed-lessons YAML template.
- `misc/skills/manage-module/scripts/scaffold-module.js` — scaffold the file.
- `misc/skills/manage-module/scripts/verify-module.js` — validate its presence and contents.
- `misc/skills/manage-module/intents/initialize.md` — describe creation and usage.
- `misc/skills/manage-module/intents/extend.md` — describe appending entries when lesson-informed changes are made.
- `misc/skills/manage-module/intents/verify.md` — include the record in the manual checks.
- `misc/skills/manage-module/reference/module-anatomy.md` — make the file part of the canonical anatomy.
- `misc/skills/manage-module/templates/workspace-readme.md` — document the record in generated module READMEs.

**Clarification before execution:** Should `CONSUMED-LESSONS.yml` record only `lesson` and `consumed_on`, or include an optional short `change`/`note` field? The latter gives the log more meaning while remaining parseable.
