# Intent: initialize-folder

Scaffold a new guide folder from an existing guide in the same repository.

## Parameters

- `topic` — required, asked interactively if missing.
- `dir` — optional; derive from the topic if absent.
- `based-on` — optional path to the guide to mirror; default to the nearest existing guide found in the repository.

## Steps

1. Resolve the repo root and inspect `AGENTS.md` for repository-specific guide conventions.
2. Read the `based-on` guide: its top-level `README.md`, its `misc/sources/` convention, and one bucket `README.md` + lesson file. Copy the *shape*, not the content.
3. Create `<dir>/misc/sources/` with a `README.md` explaining that archives are verbatim with frontmatter and that lessons do not link back to them.
4. Create `<dir>/README.md` with: purpose, status (initialised, no sources), a source table placeholder, lesson conventions (one idea per file, bucket list, enrich-not-duplicate, no `Source:` line), and a directory → pipeline placeholder. Keep bucket names consistent with the `based-on` guide unless the user specifies different ones.
5. Report the created tree and ask whether to proceed to `search-online`.

## Do not

- Copy source articles or lessons from the `based-on` guide.
- Create empty bucket directories until lessons are extracted into them.
- Modify anything outside `<dir>`.
