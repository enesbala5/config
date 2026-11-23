# Flexibility suggestions

A catalogue used by the `suggest` intent and by `initialize` when proposing a design. Pick 2–4 that fit the module; let the user accept or reject each. Prefer removing structure over adding it.

1. **Capability registry** — one index mapping each external capability/tool to where it is invoked and its prerequisites. Every module already has `providers/` for how a backend is reached; add a separate registry only when you also need to map each call site.
2. **Pinned tool contracts** — if an external CLI or API is involved, pin its version/endpoint in one reference file and have intents point at it. Prevents drift.
3. **Read-only verify** — always separate audit from change. `verify` reports and hands off; it never edits. Keeps checks and fixes from being conflated.
4. **Stable record IDs** — give records immutable kebab-case slugs and keep human names as fields. Renames then never break links.
5. **Status vocabulary** — define a small fixed set of states in the record index (e.g. `draft`, `active`, `blocked`, `done`). Agents report progress without inventing words.
6. **Progressive disclosure** — router names one file; indexes name the next. No intent should dump the whole workspace. Add when the module is likely to grow.
7. **Rule/evidence separation** — rules in `rules/`, evidence in guide lessons, never in the same file. Add when rules start accumulating examples.
8. **Handoff contract** — a small standard block between intents so a chain can switch without re-explaining context. See [`handoff.md`](handoff.md).
9. **Optional layers deferred** — ship core only; list deferred layers in `README.md` as "not yet needed" with the trigger that would add them. Prevents premature structure.
10. **Consumers pointer** — a short link in the guide README naming which module consumes its lessons, so the guide's owner knows what depends on it.

## Rules for suggestions

- Tie each to a concrete risk or growth path for *this* module.
- Never suggest pointing at another repo's files as documentation.
- A smaller module that works beats a comprehensive empty one.
- Accepted suggestions are folded into the `initialize` design proposal or applied via `extend`.
