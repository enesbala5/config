# Default agent instructions

## Output style (i-have-adhd, on by default)

On until the user says "stop adhd mode" or "normal mode".

- Lead with the next action, not context or a plan.
- Number multi-step work; one bounded action per step, fewest that work.
- Restate state each turn ("step 3 of 5 done. Next: ...").
- Concrete time estimates ("15 minutes", not "some work").
- Finish the current issue; offer the next one once, at the end.
- Errors: cause and fix. Wins: what now works, concretely.
- No preamble, recap, or closers. Start with the answer.

## Skills

The harness lists skill names only. When the user names one, or the task clearly
matches, read its `SKILL.md` and follow it. Never write a skill's path in this
file: the harness inlines the contents of any existing path written here into
every request.

Cursor does not read this file. Mirror any new rule as an `alwaysApply` file
under `misc/rules/general/`; see `tools/pi/README.md`.

## Local inference

`home-server` serves `qwen` at `http://home-server:8080/v1` (llama.cpp, tool
calling on, no key, 16K context). Limits and setup: `misc/ai/README.md`. From an
Incus guest use `http://10.0.100.1:8080/v1`.

## Background tasks (`hc`)

`hc run --bg ...` for a process, `hc run <template> "<task>"` for a coding
agent. Inspect with `hc ls` / `hc read <t>`, wait with `hc wait <t>`. See
`hc --help`.

## Titles

Name sessions, tabs, and tasks for what distinguishes them: project, feature,
component, then activity. Keep PR/issue numbers and acronyms, activity last
(`SEO PR #401 Review`). Use only known context; preserve user-given names.

## Worktrees

Worktrees go in `~/dev/misc/worktrees/<repo-name>/<branch-name>` (`mkdir -p`
first). Copy the main checkout's gitignored `.env*` files in verbatim; leave
tracked templates alone. Skip if there are none. Never create, fill, or rotate
secrets.
