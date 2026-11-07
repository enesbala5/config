---
name: worktree-pr-test
description: Check out a branch or pull request in ~/dev/misc/worktrees, merge dev into it, duplicate the worktree env, run that repo's worktree steps, and prepare the database with the commands that repo's AGENT.md or AGENTS.md documents. Use when testing a PR, branch, or local change for coverlttr or any repo that uses this worktree layout and a worktree env example.
---

# Worktree PR test

Test a branch or PR in its own worktree. Leave the main checkout as it is. Do not push. Do not create, fill, or rotate secrets.

## Inputs

- Main checkout of the repo
- Branch name or PR to test
- Base to merge (default `dev`)

## Steps

1. From the main checkout, fetch.

```bash
git fetch origin
```

2. Add the worktree at `~/dev/misc/worktrees/<repo-name>/<branch-name>`. Create the parent directory if it is missing.

```bash
mkdir -p ~/dev/misc/worktrees/<repo-name>
git worktree add ~/dev/misc/worktrees/<repo-name>/<branch-name> origin/<branch-name>
```

For a PR, use the PR head branch name in that path. Do not prefix the branch with `cursor/` or `agent/`.

3. In the worktree, merge the base. Local only. If it conflicts, stop and report the conflicts. Do not push.

```bash
cd ~/dev/misc/worktrees/<repo-name>/<branch-name>
git merge origin/dev
```

4. Duplicate env. Copy only. Do not rewrite ports, container names, or other overrides.

- Copy gitignored env files from the main checkout into the worktree: `.env` and any other gitignored `.env*` the checkout actually has (`.env.dev`, `.env.prod`, `.env.local`, and so on).
- Leave tracked templates (`.env.example` and similar). They are already in the worktree from git.
- If the repo documents a worktree env example, duplicate that example into the env file the worktree run steps expect.
- If the main checkout has no env files and there is no worktree example, skip this step.

5. Run the app from the worktree using the worktree run steps in that repo's AGENT.md or AGENTS.md (coverlttr: the worktrees section). Do not invent a different compose project, port, or start command.

6. Prepare the database for this worktree when that repo's AGENT.md or AGENTS.md documents it.

- Read that file for migrate, seed, or other database setup commands. Run those against the worktree stack (its env file, compose project, and containers).
- Do not copy commands from another repo, and do not hardcode one project's targets in this skill.
- A new worktree database starts empty. Do this before exercising the change when the doc has those steps.
- If the doc has database commands only for the main checkout, and nothing for a second stack or worktree, say so and stop. Do not guess ports, container names, or seed commands.

7. Exercise the change in that worktree. The main checkout stays on its current branch.

## Do not

- Run commands on a remote host unless the user asks in that same turn.
- Commit or push unless the user asks.
- Start `git worktree add` from a different repo's checkout.
