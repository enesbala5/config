# Intent: status

Report the current state of a guide. Read-only.

## Parameters

- `topic`, `dir` — common parameters.

## Steps

1. List archived sources in `<dir>/misc/sources/` and mark each as **extracted** or **pending** by checking whether its slug appears in any lesson file or in the guide's source table state.
2. List bucket directories and lesson counts (excluding each bucket's `README.md`).
3. Report integrity issues found by `node <skill>/scripts/verify-guide.js <dir>` and, if the `manage-lesson` skill is available, by that skill's `scripts/verify-lessons.js <dir>`.
4. Emit a handoff with `next_intent: extract-from-guide` and `next_input.source` set to the first pending source, so a sequential run has a deterministic queue.

## Do not

- Change any file.
- Guess extraction state when a source is referenced ambiguously — list it as `unknown` and say why.
