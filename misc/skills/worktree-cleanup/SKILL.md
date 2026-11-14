---
name: worktree-cleanup
description: Safely stop one worktree's verified runtime resources and remove its checkout under ~/dev/misc/worktrees. Use when finished with a task, PR, or branch prepared by multitask, or when explicitly asked to tear down a worktree.
---

# Worktree cleanup

Tear down only the worktree the user identifies. Leave the main checkout and
all other worktrees and services unchanged. This is the teardown companion to
`multitask`, not an automatic final step of that workflow.

## Inputs

- Exact worktree path, or repository plus branch/task sufficient to resolve it.
- Main checkout, when the worktree path alone is not enough.

Convention: `~/dev/misc/worktrees/<repo-name>/<branch-name>`.
Ask when the target is ambiguous; never infer it from the current directory alone.

## 1. Verify the target and protect unfinished work

From the verified main checkout, run `git worktree list --porcelain`. Confirm
the resolved target is registered, under the expected worktree parent, and not
the main checkout. Do not follow a symlink into an unrelated directory.

Inspect the target with `git status --short --branch`, including untracked files,
and check its HEAD/branch against the intended integration branch or other
known retaining refs. Local commits may be valuable even with a clean status;
a detached HEAD may lose its last worktree reference on removal. If the base or
commit retention cannot be established, treat that as unresolved work.

Before teardown, report modified/untracked source, unresolved work, and any
local database/volume data that would be deleted. Require explicit confirmation
before discarding them. Do not commit, stash, create backup refs, or delete data
automatically. Inspect ignored files too when force removal is contemplated;
do not assume all ignored files are disposable. Never print env secrets.

If the directory is already gone, inspect registration and remaining runtime
resources and report their state. Do not remove unrelated resources or run a
broad worktree prune to repair one missing checkout.

## 2. Stop only the worktree's runtime

Read the target's `AGENTS.md` / `AGENT.md` and teardown documentation. Verify
resource ownership before running even a documented command: compose working
directory, project, container mounts, database target, networks, and volumes
must identify this worktree and not the main checkout or another worktree.
Copied env files do not prove isolation.

Use the documented worktree stop command from that worktree. Do not add volume
removal flags by default. If volume/database deletion is intended, identify the
data and obtain explicit approval first. External/shared volumes are not owned
by this worktree merely because a container mounts them.

If no stop command is documented, inspect resources first, for example:

```bash
docker ps -a --filter "label=com.docker.compose.project.working_dir=<absolute-worktree-path>"
docker inspect <verified-container-ids>
```

Stop/remove only individually verified worktree containers. Inspect their
compose project labels, networks, and volumes before considering those for
removal; remove only exclusively owned resources with the necessary approval.
If ownership is ambiguous, stop and report it. Do not invent a broad compose
down command. For non-container processes, verify the exact process and working
directory rather than killing by a generic app name or port. With no runtime,
skip this step. Never use `docker system prune`.

## 3. Remove the checkout

From the main checkout, first try normal removal:

```bash
git worktree remove "<absolute-worktree-path>"
```

If removal refuses because of modified/untracked files or disposable artifacts,
inspect the reason. Use `git worktree remove --force` only after the user has
explicitly approved discarding the identified contents. Do not use a recursive
filesystem delete as a fallback. Keep branches and retained commits unless the
user separately asks to delete them.

Do not automatically close Herdr spaces or tabs: they may contain this agent or
other running work. If asked to close them, verify the exact IDs/ownership first.
Herdr is not required for cleanup.

## 4. Verify and report

Check that the directory is gone, `git worktree list` no longer includes it, and
no verified worktree container/process remains. Report any deliberately retained
volumes, branches, or blocked resources instead of claiming complete teardown.
Confirm the main checkout and other worktrees were not changed.

Do not commit, push, or run commands on a remote host unless explicitly asked.
