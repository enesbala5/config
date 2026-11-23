# Intent: extend

Add to an existing module. Read only the target module's `AGENTS.md`, `README.md` and the files being changed. Never edit guides.

## Parameters

- `name`, `scope`, `repo` — common parameters; prompt if missing. Use the scope the module was created with.
- `target` — required: what to add (`intent`, `layer`, `stage`, `rule`, `record-shape`, `gate`, `capability`). If missing, list the options and ask.
- `change` — required: the actual addition. If vague, ask for specifics before editing.

## Recipes

| Target | Change | Cost |
|---|---|---|
| `intent` | Add `intents/<intent>/README.md`, one router row, one `AGENTS.md` pointer | Small |
| `stage` | Add `pipeline/<stage>/README.md`, one row in `pipeline/README.md` | Small |
| `gate` | Add one bullet to the module's `AGENTS.md`; do not duplicate it in intents | Tiny |
| `rule` | Add a file under `rules/`, one index line, with lesson evidence | Small |
| `layer` | Add the optional layer's README, wire an index line; move detail out of `AGENTS.md` | Medium |
| `record-shape` | Add the record template under `projects/`, update its index | Small |
| `capability` | Add one row to the capability registry; intents reference the row | Small |

## Rules

- After any extension, update the **index that owns it**, then run `node scripts/verify-module.js <root> <name> --scope <scope>`.
- A new rule must follow [`../reference/rules-from-lessons.md`](../reference/rules-from-lessons.md) — one enforceable statement with evidence, never copied lesson prose.
- New intent names must appear in the router and in `AGENTS.md`; the verifier checks router rows against intent folders.
- Prefer removing structure over adding it. If an extension can be expressed as one index line, do that.
- Flexibility ideas live in [`../reference/flexibility.md`](../reference/flexibility.md) — use it to decide whether a registry, pin or status vocabulary is warranted before adding ad-hoc structure.

## Handoff

On success → `verify` for a structure check, then done. If a router row changed, re-run the `initialize` router handoff to `manage-skill` with the module's resolved scope.
