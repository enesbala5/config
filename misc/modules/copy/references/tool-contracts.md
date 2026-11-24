# Tool contracts

Pinned contracts for external capabilities used by this module. An intent names
this file when it reaches a backend; the gates for using one stay in
`<config>/misc/modules/copy/AGENTS.md`. Any CLI or API here has a file/shell
fallback, so the module works without a particular harness tool.

## Voice and messaging cache

- Reader: `<config>/misc/modules/copy/references/scripts/repo-file.sh`.
- Usage: `bash <config>/misc/modules/copy/references/scripts/repo-file.sh <owner/repo> <branch> <path> [path...]`.
- One clone per repo; at most one pull per TTL (`REPO_CACHE_TTL`, default `21600`
  seconds). Cache root is `REPO_CACHE_DIR`, default `$HOME/.hermes/cache/repos`.
- A failed pull warns and serves the cached copy; say so in one line when it happens.
  Never clone or call the GitHub contents API in parallel with the reader.
- Fallback when the script is absent:
  `gh api repos/<owner>/<repo>/contents/<path>?ref=<branch> -q .content | base64 -d`,
  with a one-line notice that the cache is unavailable.
- Target registers and their source paths are listed in
  `<config>/misc/modules/copy/references/x/personal.md` and
  `<config>/misc/modules/copy/references/x/coverlttr.md`. Add a target by adding one
  reference and one row; never blend registers.

## Recent-work material

- Reader: `<config>/misc/modules/copy/references/scripts/recent-work.sh`, with `[hours]` and optional `[owner/repo ...]` arguments.
- Default window is 36 hours; the repo list is configurable through positional
  arguments. A repo with nothing in the window says so explicitly.
- Pick a change with a real story (decision, bug, trade-off, lesson), not the
  largest diff. A commit message alone is not a story.

## Topical search

- At most two `web_search` queries per X batch, in lanes the author has standing in.
- An item qualifies only when it is real, recent, and has a non-obvious take. Its
  `from:` line names the outlet and date exactly as the search returned them.
- If nothing qualifies, ship another build-in-public option and say so in one line.
  A paraphrase dressed up as reporting is not a source.

## Delivery ledger

- Append-only JSONL, default `$HOME/.hermes/x-posts/delivered.jsonl`; override with
  `COPY_X_LEDGER`. One object per option:
  `{"id": "<repo>:<sha|slug>", "target": "...", "voice": "...", "angle": "...", "text": "...", "at": "<ISO8601>"}`.
- Read the last 200 lines before drafting; drop any commit, PR or angle delivered
  in the previous 14 days. The ledger is the only archive: no batch files, reports
  or scratch documents.

## Reply validation

- Optional local validator, path from `COPY_X_VALIDATOR`. If unset or absent, use
  the mechanical checks in the social rules (dashes, links/bare domains, banned
  openers) and treat its character-count and terminal-punctuation lints as
  informational for live replies.

## Anti-AI voice dependency

- The `voice` skill (installed under `voice` or `voicer`) owns the list of tells.
  Load it by the name this install has; with no skill loader, read
  `<config>/misc/skills/voice/SKILL.md` directly.
- Take its rules, never its output format. A comment reply stays one recommended
  response plus one alternative, not a draft/audit/final triple.

## Project-owned sources

- The page-type-by-awareness ladder lives in the working repo (Coverlttr:
  `docs/marketing/page-types-by-awareness.md`). It is the single source of truth;
  this module never restates its mapping.
- Product-marketing context is read from the working repo's documented location
  before page or edit work.
- Blog code fences stay on the portfolio's highlighter list: `javascript`,
  `typescript`, `bash`, `json`, `svelte`, `ini`, `properties`, `ssh-config`, `nix`.
