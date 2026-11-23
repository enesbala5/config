# Intent: verify

Read-only structure check for a module. Never edits.

## Parameters

- `name`, `scope`, `repo` — common parameters; prompt if missing. Use the module's resolved scope.

## Steps

1. Run `node scripts/verify-module.js <root> <name> --scope <scope>`. It checks required files, router frontmatter and intent rows, token and relative paths, unrendered template tokens, absolute/home-relative paths, and references to other modules or repositories.
2. Additionally inspect by reading:
   - router router rows match the approved intent list;
   - `AGENTS.md` holds gates only, not workflow prose or lesson content;
   - each intent file names its handoff and does not restate sibling flows;
   - rules point to lesson evidence and never copy lesson text;
   - `LEARNINGS.md` uses the declared status vocabulary.
3. Report findings grouped by file with exact paths. Separate **blocking** problems (broken links, missing router) from **advisory** ones (thin rule, verbose AGENTS.md).

## Handoff

Blocking or advisory problems → `extend` with `target` set to the owning file. No problems → done. Never fix anything from this intent.
