# Clean up a worktree

A cleanup request is enough to start this procedure; do not ask for a separate
confirmation to begin. Confirmations for forced removal, discarding work or
data, and Herdr closure still apply.

Tear down only the worktree the user identifies. Leave the main checkout and
all other worktrees and services unchanged. This is the teardown companion to
[setup](../setup/README.md), not an automatic final step of that workflow.

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

## 3. Identify the matching Herdr space

When Herdr is available in this session, inspect its installed CLI and live
state before removing the checkout. For the Desktop integration used during
[setup](../setup/README.md), inspect `herdr-app commands` and `herdr-app ls`. Record the exact
space ID whose folder matches the verified absolute worktree path; do not
identify it by title, sidebar order, or indentation alone. Do not open Herdr
just for cleanup. If no space matches, skip Herdr cleanup; if ownership is
ambiguous, ask rather than guessing.

Ask the user whether to close that specific space after successful checkout
removal. Explain that otherwise it will remain with a missing folder and may
lose its worktree grouping. Never close a space or its tabs without this
confirmation. If other terminals contain active agents or processes, identify
them and obtain explicit approval before closing them; approval to remove the
checkout alone does not authorize terminating unrelated work.

If this agent occupies the target space, preserve its terminal before closure:
identify the verified main-checkout space, move the current terminal there using
the installed CLI's supported attachment commands, and change its working
directory to the main checkout. Verify the move in live state. Do not create a
new space, kill the current terminal, or close its containing space as a fallback.
If safe relocation is unavailable, leave the space open and report the blocker.

Herdr is optional: unavailable inspection or declined closure does not prevent
otherwise safe worktree removal. Record any space left behind for the report.

## 4. Remove the checkout

Any forced removal requires explicit user confirmation for the specific target
and reason; a request to start cleanup does not provide that confirmation.

From the main checkout, first try normal removal:

```bash
git worktree remove "<absolute-worktree-path>"
```

If removal refuses because of modified/untracked files or disposable artifacts,
inspect the reason. Use `git worktree remove --force` only after the user has
explicitly approved discarding the identified contents. Do not use a recursive
filesystem delete as a fallback. Keep branches and retained commits unless the
user separately asks to delete them.

Only after checkout removal succeeds, recheck the recorded Herdr space ID and
folder ownership. If the user approved closure and its terminals are safe to
close, close only that space using the installed CLI's supported command.
Never close the parent repository space, unrelated tabs, or a workspace group.
If closure fails, inspect state before retrying and report any remaining space.
Do not claim Herdr cleanup succeeded merely because the checkout is gone.

## 5. Verify and report

Check that the directory is gone, `git worktree list` no longer includes it, and
no verified worktree container/process remains. Report any deliberately retained
volumes, branches, or blocked resources instead of claiming complete teardown.
Verify an approved Herdr space closure in live state. Report whether its space
was removed, absent, deliberately retained, or blocked, including any missing-folder
space left behind. Confirm the main checkout, parent repository space, and other
worktrees/spaces were not changed apart from any approved terminal relocation.

Do not commit, push, or run commands on a remote host unless explicitly asked.
