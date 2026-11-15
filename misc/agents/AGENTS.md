# Default agent instructions

Always apply the `i-have-adhd` skill (`~/.agents/skills/i-have-adhd/SKILL.md`)
in every response. The skill is the spec; this file only points at it. Stays on
until the user says "stop adhd mode" or "normal mode".

Cursor does not load this file. Any rule added here also needs a matching
`alwaysApply` file under `misc/rules/general/`. See `tools/pi/README.md`
("Default instructions").

## Background tasks (`hc`)

Use `hc` to spawn background tasks and subagents: `hc run --bg …` for a
background process, or `hc run <template> "<task>"` for a coding-agent
template. Inspect with `hc ls` / `hc read <t>`; wait with `hc wait <t>`.
See `hc --help`.

## Distinctive session and tab titles

When naming a session, tab, or task in any harness, make its purpose easy to
recognize among neighboring tabs. Lead with the concrete project, feature,
component, or topic; preserve identifying PR/issue numbers and acronyms; put
the activity after the identifying detail. Prefer `SEO PR #401 Review` over
`Reviewing pull request`, and `Coverlttr Stripe Webhooks` over `Fixing bugs`.
Keep titles short, but never remove the detail that distinguishes the task.
Use only known context; do not invent identifiers. Preserve explicit user names.
Apply this whenever the harness supports setting a title or session name.

## Git worktrees

Put git worktrees at `~/dev/misc/worktrees/<repo-name>/<branch-name>`.
If that directory does not exist, create it first (`mkdir -p`).
Cursor, pi, and every other agent use this path.

After the worktree exists, copy the main checkout's local env files into it
when that checkout has any. That is `.env` and any other gitignored `.env*`
the main checkout actually has (`.env.dev`, `.env.prod`, `.env.local`, and so
on). Leave tracked templates alone (`.env.example` and similar); they are
already in git. If the main checkout has no env files, skip this.

Copy only. Do not rewrite the copies with worktree-only ports, container
names, or other overrides. The copies keep the same secrets and defaults as
the main checkout. Do not create, fill, or rotate secrets.
