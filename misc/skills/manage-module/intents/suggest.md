# Intent: suggest

Review a module design or an existing module for flexibility, and propose improvements. Read-only until the user accepts a suggestion.

## Parameters

- `name`, `scope`, `repo` — common parameters; prompt if missing.
- `focus` — optional: a concern to concentrate on, e.g. "growing intents", "external tooling", "stateful work". If missing, review all categories.

## Steps

1. Read the module's `AGENTS.md`, `README.md` and indexes. If the module does not exist yet, read the proposed design from the `initialize` intent instead.
2. Read [`../reference/flexibility.md`](../reference/flexibility.md).
3. Choose 2–4 suggestions that fit the module's purpose and current risks. For each: name it, say why it fits, state the concrete change, and note the cost.
4. Explicitly say which suggestions you are **not** recommending and why — smaller modules are usually better.
5. Stop for approval. Do not apply anything until the user picks.

## Output

A short table: `suggestion | why now | change | cost`. Then a question: which to apply? Accepted suggestions hand off to `extend`; if the module does not exist yet, fold them into the `initialize` design proposal before scaffolding.
