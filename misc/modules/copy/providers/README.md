# Providers

External backends this module uses. A provider is a backend that supplies
something the work needs — a source file, a search result, a history, a record.
This index says what each one supplies, how it is reached and what it costs.
Workflow rules and approval gates live in the workspace `AGENTS.md`, never here.

## Entries

| Provider | Supplies | Reached through | Spend |
| --- | --- | --- | --- |
| `github-voice-cache` | Voice and messaging files (TONE.md, PROFILE.md, Coverlttr docs) | `<config>/misc/modules/copy/references/scripts/repo-file.sh`; one clone per repo, at most one pull per TTL; `gh api` fallback | One shallow clone, ≤1 pull per TTL per repo |
| `web-search` | Recent topical X material in the author's standing lanes | `web_search`, at most two queries per batch; exact outlet and date recorded in the `from:` line | ≤2 search calls per batch |
| `git-history` | Receipts and storyline for referenced repos | `git -C <path> log --follow` / `git show --stat` on the local checkout | Local commands only; no remote SSH |
| `local-ledger` | 14-day dedupe of delivered X angles | Append-only JSONL, default `$HOME/.hermes/x-posts/delivered.jsonl`, override with `COPY_X_LEDGER` | One local file, append-only |

The `voice`/`voicer` skill is a local dependency, not a backend: it owns the
anti-AI tell list and is read by name or from `<config>/misc/skills/voice/SKILL.md`.
