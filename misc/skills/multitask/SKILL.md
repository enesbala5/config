---
name: multitask
description: Set up an isolated git worktree from a PR link, branch, or task description without disturbing the main checkout. Use to test a PR, work on another branch, or start a separate task. Includes env copying, documented app/database setup when needed, and optional Herdr Desktop workspace attachment. Replaces worktree-pr-test.
---

# Multitask

One entry point for starting isolated work. All setup lives here; there is no
separate setup skill. Use `worktree-cleanup` when the user is done.

A single task is enough. Multiple independent tasks get separate worktrees;
do not split dependent changes or launch agents merely because of the name.

## 1. Resolve the request

Identify the main checkout, the requested activity (setup only, test, investigate,
or implement), and one of these inputs:

- **PR URL or number:** resolve the PR's repository, head commit, head branch,
  and base branch. A number alone needs repository context. Use authenticated
  GitHub CLI (`gh auth status`) when available:
  `gh pr view <url-or-number> --json number,url,headRefName,headRefOid,baseRefName,isCrossRepository`.
  Without `gh`, use GitHub's REST API (`GET /repos/{owner}/{repo}/pulls/{number}`;
  `GH_TOKEN` for private repositories) and Git. If metadata or credentials are
  unavailable, ask for the head/base details; do not guess or print tokens.
- **Branch:** resolve the exact local branch or remote ref. If local and remote
  differ, clarify which to use rather than resetting either.
- **Task description:** choose a descriptive new branch name and resolve its
  starting base from the user's request or explicit repository instructions.
  Ask if the base is ambiguous. Validate with `git check-ref-format --branch`.

Read the repository's applicable `AGENTS.md` / `AGENT.md` and worktree/run docs.
Inspect `git status --short`, `git remote -v`, and `git worktree list` from the
main checkout. Confirm a PR URL belongs to this repository before fetching it.
Leave the main checkout's branch, index, and files unchanged.

A PR defaults to its **exact head**, not a merge with `dev`. Merge a base only
when requested or explicitly required by repository instructions. If the user
asks to merge but the base is unspecified, confirm it first.

## 2. Create or reuse the worktree

Use `~/dev/misc/worktrees/<repo-name>/<branch-name>` per the shared convention.
Preserve existing branch names (including slash-separated components); do not
add an agent or harness prefix. For a PR, use its head branch name for the path.
Resolve paths and ensure the destination stays under this repository's worktree
parent. Quote paths and refs; never interpolate untrusted PR text into shell code.

From the verified main checkout:

```bash
mkdir -p "$HOME/dev/misc/worktrees/<repo-name>"
```

Fetch only the relevant remote/ref. Examples below use placeholders, not literal
commands to run unchanged:

```bash
# Existing local branch, not already checked out elsewhere:
git worktree add "<worktree-path>" "<local-branch>"

# Existing remote branch, isolated without moving a local branch:
git fetch <remote> <branch>
git worktree add --detach "<worktree-path>" "<resolved-remote-commit>"

# New task branch:
git worktree add -b "<new-branch>" "<worktree-path>" "<confirmed-base-ref>"

# GitHub PR, including a fork PR; fetch from the verified base repository:
git fetch <base-remote> refs/pull/<number>/head
git worktree add --detach "<worktree-path>" FETCH_HEAD
```

For PRs, verify the checkout matches the resolved head commit; if it changed
during setup, refresh the metadata and report the actual commit tested. A
detached checkout is suitable for testing; if implementation is requested,
create an unused local task branch there before editing.

If the destination exists or the branch is already checked out, inspect it.
Reuse only a verified matching worktree without discarding its work. Otherwise
ask for a distinct branch/path. Never force-add, reset, clean, or remove it.

For an explicitly requested base merge, run it only inside the worktree. Report
conflicts and stop; do not automatically resolve or push. A detached test merge
may create a local integration commit only when the merge was authorized;
otherwise do not commit. Record head and base SHAs and the resulting test mode.

Use an explicit worktree working directory for every subsequent command;
a shell `cd` may not persist between tool calls.

## 3. Copy env and optionally start the app

Copy only the main checkout's existing gitignored `.env` and `.env*` files to
matching paths in the worktree. Check ignored/tracked status with
`git check-ignore` and `git ls-files`; do not overwrite tracked files, follow
symlinks outside the checkout, print secrets, or overwrite different env files
in a reused worktree without approval. Leave tracked templates alone. If no
local env files exist, skip copying.

Do not rewrite ports, container names, credentials, or other values. Do not
create, fill, or rotate secrets. Copy a documented worktree env template only
when repository instructions require it, without overwriting copied local env.

For setup-only work or checks that need no running app, skip app/database startup.
Otherwise:

1. Use only the repository's documented worktree install/start commands.
2. Verify ports, compose project, containers, database targets, and volumes are
   isolated from the main checkout and other worktrees **before** starting or
   migrating. Copied env files alone do not establish isolation.
3. Run documented worktree migrations/seeding before exercising the change.
   Never run main-checkout database commands against an assumed second stack.
4. If documented isolation or setup is missing, or copied defaults collide,
   leave the worktree prepared and report the blocker. Do not invent overrides.

## 4. Optionally attach to Herdr Desktop

Herdr is a convenience, not a prerequisite. Use this integration when explicitly
requested, or when already inside a Herdr Desktop pane: `herdr-app` and `hc`
exist, `HC_TERMINAL_ID` is set, and `herdr-app ls` successfully reports the open
window. Do not open the app or require its installation just for this skill.

Inspect `herdr-app commands` and `hc --help` before using version-dependent
commands. Inspect `herdr-app ls` for a space whose folder or terminal cwd matches
the worktree; reuse it rather than creating duplicates. Use a distinctive title
such as `<repo> PR #<number> Test` or `<repo> <task>`, preserving known identifiers.

When the installed command interface supports it, create a space as follows:

```bash
herdr-app do space.new --name "<distinctive-title>" --folder "<absolute-worktree-path>"
```

Read the returned space/tab/placeholder terminal IDs. To attach the current
Desktop terminal, label it with the destination and select the space:

```bash
hc label "$HC_TERMINAL_ID" "herdr.space=<space-id>" "herdr.tab=<tab-id>"
herdr-app do space.select --id "<space-id>"
```

Verify with `herdr-app ls` that the current terminal is in the intended space.
Only then kill the newly created placeholder terminal using
`herdr-app do terminal.kill --terminal "<placeholder-id>"`. Never kill the
current terminal or any pre-existing terminal. If attachment is unsupported or
fails, leave terminals intact and report it; worktree setup can still succeed.

Without Herdr, use the same worktree directly through shell commands with its
working directory set explicitly. In an ordinary terminal, the user can run
`cd "<absolute-worktree-path>"`. No multiplexer or agent harness is required.
Do not launch agents unless the user asks; if asked, follow the environment's
available launcher instructions and give each agent its own task/worktree.

## 5. Perform the requested work and hand off

Setup alone is not permission to implement changes. For a testing request,
inspect the diff and run relevant documented checks; for implementation, follow
the requested task in the isolated worktree. Do not push or open PRs unless asked.
Do not run commands on remote hosts without explicit authorization.

Verify `git worktree list` and worktree `git status --short --branch`. Confirm
the main checkout's branch/index/files remain unchanged. Report:

- Task/PR, branch or detached head, and absolute worktree path.
- Exact head/base SHAs and whether a base was merged, when testing a PR.
- Checks actually run and their results; distinguish setup from verified tests.
- App URL/runtime ownership and Herdr attachment, if applicable; any blockers.
- Use `worktree-cleanup` with this exact path when finished. It also asks whether
  to close the worktree's dedicated Herdr space after successful checkout removal,
  while protecting active terminals and the parent repository space. Do not tear
  down automatically or claim the new task's work has been integrated.
