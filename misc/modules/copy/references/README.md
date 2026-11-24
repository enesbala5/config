# References

Capture formats and templates used by this module. A reference is read only when
an intent names it.

## Entries

### Contracts

- `tool-contracts.md` — pinned reach and fallbacks for the voice cache, recent-work material, topical search, ledger, validator, voice dependency and project-owned sources. Used by `social`, `write`, `longform`, `verify`.
- `output-contracts.md` — the hand-off shape for each intent. Used by all intents at delivery time.

### Page copy (`write`)

- `copy-frameworks.md` — headline formulas and page-section templates.
- `natural-transitions.md` — transition phrases for section flow.

### Editing (`revise`)

- `checklist.md` — full QA checklist across the seven sweeps.
- `content-refresh.md` — refresh/rewrite decision matrix, checks and cadence.
- `plain-english-alternatives.md` — simpler replacements for weak words.

### Social (`social`)

- `repo-cache.md` — clone-once/TTL contract for voice-source reads.
- `scripts/repo-file.sh` — the single module-owned cached reader for X batches and comment replies.
- `scripts/recent-work.sh` — recent commits and merged PRs used as build-in-public material.
- `x/personal.md` — personal register and source paths.
- `x/coverlttr.md` — brand register and source paths.
- `x/example-batch.md` — a full batch with `from:` lines.
- `replies/example-cover-letter-thread.md` — reference reply for the house shape.

### Longform (`longform`)

- `blog/excerpts.md` — voice calibration snippets from published posts.
- `blog/repo-storyline.md` — git-history command list and clustering filters.

## Convention

- One format per file; no workflow rules here (those live in `AGENTS.md`, a rule set, or the intent).
- Machine-specific defaults are named with an environment override; no absolute machine paths.
- These files were re-homed from the five source skills before those skills were removed.
