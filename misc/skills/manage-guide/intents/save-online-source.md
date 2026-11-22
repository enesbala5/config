# Intent: save-online-source

Archive the user's selected sources as verbatim Markdown in `<dir>/misc/sources/`.

## Parameters

- `topic`, `dir` — common parameters.
- `selected` — required: shortlist numbers, URLs, or explicit source names. **If missing, print the current shortlist and ask the user to pick**, then continue.

## Steps

1. Resolve each selected entry to its URL from the guide's source table.
2. Fetch and convert using [`../reference/md-tooling.md`](../reference/md-tooling.md):
   - Web pages: portable path is `curl` → raw HTML → `node <skill>/scripts/convert-html-to-md.js`. The browser-MCP shortcut is optional.
   - X: `node <skill>/scripts/fetch-x-to-md.js <status-id> <out.md>` — X pages are login-gated, so use the public JSON API and save the full post/article text.
3. Each output file gets frontmatter: `title`, `source` (URL), `author`, `published`, `captured`, then the full body. Do not summarize, editorialize or pad.
4. Save with a short kebab-case slug matching the source title. Refuse to overwrite an existing file without asking.
5. Update `misc/sources/README.md` with the archived file list.
6. Run `node <skill>/scripts/verify-guide.js <dir>` and fix any problems.

## Verification

- Every selected source has exactly one MD file.
- Bodies are complete (check the ending, not just the word count).
- No file is a stub or a snippet.

## Do not

- Create lesson files — that is `manage-lesson`.
- Add `Source:` lines to lessons; frontmatter here is for the archive only.
