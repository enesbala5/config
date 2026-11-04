# Default agent instructions

Always apply the `i-have-adhd` skill (`~/.agents/skills/i-have-adhd/SKILL.md`)
in every response. The skill is the spec; this file only points at it. Stays on
until the user says "stop adhd mode" or "normal mode".

Cursor does not load this file. Any rule added here also needs a matching
`alwaysApply` file under `misc/rules/general/`. See `tools/pi/README.md`
("Default instructions").

## Git worktrees

Put git worktrees at `~/dev/misc/worktrees/<repo-name>/<branch-name>`.
If that directory does not exist, create it first (`mkdir -p`).
Cursor, pi, and every other agent use this path.
