---
name: chunk-and-commit
description: >-
  Split uncommitted work into logical git commits, present each proposed
  commit (message plus file chunk) for confirmation, then commit only after
  the user approves. Use when the user asks to commit, chunk commits, split
  commits by article/feature/file, or commit all changes in groups.
---

# Chunk and commit

Inspect the working tree, group changes into reviewable commits, **show the
plan**, wait for yes, then commit. Do not run `git commit` until the user
confirms the proposed list.

Honor grouping the user already named in this turn (e.g. "telegram and smartd
together"). Do not invent extra commits for formatting-only noise.

## When to use

- "commit all changes" / "chunk them" / "split into commits"
- "commit by article" / "by feature" / "logical commits"
- any commit request where the diff is more than one coherent unit

## Workflow

```text
git status + git diff (+ cached) + git log (in parallel)
        ↓
group files into commits (linked work stays together)
        ↓
draft the proposal (message + file list per commit) — stop
        ↓
user confirms / edits grouping or messages
        ↓
stage each chunk and commit in order
        ↓
git status to verify
```

### 1. Inspect

Run in parallel:

- `git status`
- `git diff` and `git diff --cached`
- `git log` (recent messages, so new ones match this repo)

Do not update git config. Do not skip hooks. Do not push unless asked.

### 2. Group

One commit = one reason a reviewer would want those files together.

- **Feature / article / bug**: the primary files plus assets they need
- **Linked work**: keep together when one change is useless or broken without
  the other (shared helper + first consumer, related posts, component +
  mdsvex export)
- **Shared infra**: own commit *first* only if several later chunks depend on
  it and it is not owned by one of them; otherwise attach it to the first
  consumer
- **Unrelated leftover**: its own commit, last, or call it out and leave
  unstaged if it looks accidental
- **Secrets**: never stage (`.env`, credentials, private keys). Warn instead

Prefer fewer, coherent commits over a file-by-file split.

### 3. Draft messages

Match this structure (user rule), even if older repo commits are looser:

```text
TITLE

- bullet item summarizing a change
- another bullet item
```

- **TITLE**: short imperative, no trailing period, no `feat:` / `fix:` unless
  this repo already uses that
- Blank line, then 2–6 bullets; skip mechanical noise
- Focus on why/what landed, not a file laundry list

### 4. Present the proposal (required, before any commit)

Stop. Show every proposed commit in order. Do not stage yet.

```markdown
**Commit 1:** TITLE

- bullet
- bullet

Files:
- path/a
- path/b
```

If a file could sit in two chunks, say where you put it and why. If the user
already specified grouping, reflect that in the plan.

Ask them to confirm, reorder, merge, split, or edit messages.

### 5. Commit only after confirmation

Treat "yes" / "go" / "lgtm" / an edited list as approval of *that* plan.
If they change grouping or copy, revise the proposal or commit the edited
version — do not silently revert to the old plan.

For each approved commit, in order:

1. `git add` only that chunk's paths
2. `git commit` with the full message via HEREDOC (no `-i`, no `--no-verify`
   unless they asked)
3. After the last one: `git status`

If a hook fails, fix and make a **new** commit. Do not `--amend` unless they
asked, HEAD is yours, and it has not been pushed.

Do not commit when there is nothing to commit.

## Git safety (unchanged)

- Never `push --force`, hard reset, or skip hooks unless they asked in this turn
- Never `--amend` a pushed commit unless they asked (needs force-push)
- Never prefix branches with `cursor/`
- Do not push unless they asked
