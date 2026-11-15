# Cached repo reads

Voice, messaging, and product files live in his GitHub repos. Reading them per run must not mean cloning or calling the GitHub API every time. One script owns that:

```bash
bash scripts/repo-file.sh <owner/repo> <branch> <path> [more paths...]
```

It prints each requested file to stdout, with a `===== <path>` header when more than one path is asked for. Any number of paths from the same repo in one call.

```bash
bash scripts/repo-file.sh enesbala5/portfolio main misc/TONE.md misc/PROFILE.md
bash scripts/repo-file.sh enesbala5/coverlttr dev docs/marketing/messaging.md
```

## Contract

- **Cache location:** `$REPO_CACHE_DIR`, default `~/.hermes/cache/repos/<owner>__<repo>`. One clone per repo, shared by every skill that reads it.
- **First call for a repo:** shallow clone (`--depth 1 --single-branch`) of the requested branch.
- **Later calls:** the script pulls only when the clone's last fetch is older than the TTL, default 21600 seconds (6 hours). Inside the window it reads the working tree straight from disk, no network.
- **Force a refresh:** `REPO_CACHE_TTL=0 bash scripts/repo-file.sh ...`. Use it when a doc is known to have just changed, not routinely.
- **Branch changes:** the clone records its branch in `.hermes-branch`; asking for a different branch re-clones rather than serving the wrong tree. Default branch of `coverlttr` is `master`, but the marketing docs are on `dev`, so the branch argument is not optional.
- **A failed pull is not a failure.** The script warns on stderr and serves the cached copy. Stale voice docs beat no voice docs, but mention it in the batch if a pull failed.
- **Locking:** an `mkdir` lock next to the clone serialises concurrent runs (the cron batch and an ad hoc ask can overlap). A lock older than five minutes is treated as stale and cleared.
- **Auth:** plain `https://github.com/...` clone, so the `gh` credential helper must be configured (`gh auth setup-git`). Without it a private repo fails and the script says so.
- **Missing paths** are reported on stderr at the end while the paths that do exist are still printed; exit code is 1 if any requested path was missing.

## Rules

1. Never `git clone` or `gh api repos/.../contents` in a session that has this script. Two paths to the same files is how the cache goes stale in one place and fresh in another.
2. Never edit the cache by hand. It is a read-only mirror of a branch; a `reset --hard` will discard anything written there.
3. `comment-response` uses the same script as `../draft-x-posts/scripts/repo-file.sh` (both live in the same skills directory), so the cache is shared and one pull serves both skills. If the sibling script is missing, fall back to `gh api repos/<repo>/contents/<path>?ref=<branch> -q .content | base64 -d` and say so in one line.
4. Durable facts belong in the repo, not in a skill. When something read this way is worth keeping, add it to the source file on the right branch.
