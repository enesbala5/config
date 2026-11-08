---
name: worktree-cleanup
description: Stop one worktree's containers and delete its folder under ~/dev/misc/worktrees. Use when the user is done testing a PR or branch, asks to tear down or delete a worktree, or after worktree-pr-test.
---

# Worktree cleanup

Tear down one worktree from `worktree-pr-test`. Leave the main checkout and every other worktree as they are.

## Inputs

- Repo name
- Branch or PR head name (the directory name)
- Main checkout, when the worktree path alone is not enough

Path: `~/dev/misc/worktrees/<repo-name>/<branch-name>`

## Steps

1. From the main checkout, run `git worktree list`. Continue only if that path is listed. If the directory is already gone and no container still uses it, say so and stop.

2. Stop that worktree's stack only. Read `AGENT.md` or `AGENTS.md` in the worktree for the stop command. Coverlttr, from the worktree:

```bash
./misc/bin/deploy.sh dev down --remove-orphans -v
```

That removes this project's containers, network, and volumes. Run it in the worktree, so `.env.worktree` selects this project.

If the repo documents no stop command, remove containers whose `com.docker.compose.project.working_dir` label is this worktree's absolute path, then remove volumes and networks that belong to that same compose project.

3. From the main checkout:

```bash
git worktree remove --force ~/dev/misc/worktrees/<repo-name>/<branch-name>
```

`--force` is expected. The folder holds untracked env files, `node_modules`, and build output.

4. Check all three: the directory is gone, `docker ps -a` has no container for this working directory or project, and `git worktree list` no longer includes the path.

## Do not

- Delete a worktree the user did not name.
- Stop or remove the main checkout's containers, or another worktree's.
- Run `docker system prune`.
- Commit, push, or run commands on a remote host.
