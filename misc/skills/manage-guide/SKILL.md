---
name: manage-guide
description: Build and maintain evidence-backed guide folders. Use for initialize-folder (scaffold a topic guide from an existing guide), search-online (research and shortlist web/X articles), save-online-source (archive selected articles and X posts as Markdown), status, and verify. Triggers include "set up a guides folder", "find articles for a guide", "save these sources as MD", "check the guide state".
---

# Manage guides

A guide is a topic folder that holds verbatim source articles plus extracted lessons, following the pattern of an existing guide in the same repository (for example `misc/guides/ugc/`). This skill owns the **folder and its sources**. Creating, editing and deleting lessons belongs to `manage-lesson`.

Run **one intent at a time**. Pick the intent from the user's request; if the request is ambiguous, list the intents and ask which one. Do not do two intents in one pass unless the user asks for the chained workflow.

## Common parameters

| Parameter | Meaning | Resolution |
|---|---|---|
| `topic` | Short subject name, e.g. `web design`, `ugc` | If missing, **ask the user** — never guess |
| `dir` | Repository-relative guide directory | Explicit value wins; otherwise derive `<repo>/misc/guides/<topic-slug>/`; if the repository layout does not support that derivation, ask |
| `based-on` | Existing guide to mirror | Optional; default to the nearest existing guide in the repository |

Every intent has its own extra parameters below. **If a required parameter is missing, prompt the user interactively before writing anything** — show the known options (shortlist entries, file paths) rather than asking in the abstract.

Resolve the repository root with `git rev-parse --show-toplevel`. Inspect `AGENTS.md` and `git status --short` first; preserve unrelated changes; never commit unless asked.

## Intents

| Intent | Extra parameters | Result |
|---|---|---|
| [`initialize-folder`](intents/initialize-folder.md) | `based-on` | Scaffold `<dir>/misc/sources/`, top-level README with source table, lesson conventions and pipeline placeholder |
| [`search-online`](intents/search-online.md) | `count` (default 10), `focus` | Ranked shortlist with rationale; **hard stop for user selection** |
| [`save-online-source`](intents/save-online-source.md) | `selected` (shortlist numbers or URLs) | Verbatim MD files with frontmatter in `<dir>/misc/sources/` |
| [`status`](intents/status.md) | — | Report of sources, extraction state, per-bucket lesson counts, integrity issues |
| [`verify`](intents/verify.md) | — | Frontmatter and file completeness checks; read-only |

## Complete workflow

The intents are designed to run one after another with a structured handoff between them. See [`reference/workflow.md`](reference/workflow.md) for the full sequence and the exact prompt to give each subagent, and [`reference/handoff.md`](reference/handoff.md) for the handoff block format. The `search-online` step is a user gate: stop and wait for a selection before continuing.

## Tooling

Sources must be saved as Markdown, including X posts. [`reference/md-tooling.md`](reference/md-tooling.md) documents the portable `curl` + Node converter path (the required fallback), the optional browser-MCP shortcut, and the X API endpoints. Scripts live in [`scripts/`](scripts/) and are resolved relative to this skill folder, not the caller's working directory.

## Verification

Before declaring an intent done:

1. All files written are under the resolved `dir` (except read-only inspection).
2. Every archived source has frontmatter (`title`, `source`, `author`, `published`, `captured`) and a non-truncated body.
3. `node scripts/verify-guide.js <dir>` reports no problems (run it for `save-online-source` and `verify`).
4. Report the intent, paths changed, and anything left waiting on the user.

## Failure handling

- Fetch fails or page is login-gated → try the documented fallback; if still blocked, report the URL and stop, do not save a stub.
- Conversion produces a suspiciously short body → re-check the saved HTML and re-run; never pad or summarize the archive.
- A source already exists → do not overwrite silently; report and ask.
