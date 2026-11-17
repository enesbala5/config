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

## Local web links

When sharing a local web-app link, also run `network-serve <local-url>` on the
machine hosting the app and include `Network: <returned-url>`. Use
`network-serve --skill` for usage. If forwarding fails, report it; do not invent
a network URL.

## Local inference

`home-server` serves `qwen` at `http://home-server:8080/v1` (llama.cpp, tool
calling on, no key, 16K context). Limits and setup: `misc/ai/README.md`. From an
Incus guest use `http://10.0.100.1:8080/v1`.

## Background tasks (`hc`)

Prefer background jobs for slow or unpredictable commands: Docker builds,
pulls/pushes and Compose startup, long tests, installs, and deployments.
Keep quick checks (e.g. `docker ps`) in the foreground. Prefer
`hc run --bg ...` for processes; `hc run <template> "<task>"` for coding
agents. See `hc --help`. If unavailable, use a background mechanism that
preserves logs and exit status.

Track the task ID; inspect with `hc ls` / `hc read <t>`, wait with
`hc wait <t>`. Do independent work meanwhile; avoid tight polling and
repeated full-log reads. Check completion and exit status before dependent
work or claiming success. Backgrounding never bypasses required approvals.

## Titles

Name sessions, tabs, and tasks for what distinguishes them: project, feature,
component, then activity. Keep PR/issue numbers and acronyms, activity last
(`SEO PR #401 Review`). Use only known context; preserve user-given names.

## Worktrees

Worktrees go in `~/dev/misc/worktrees/<repo-name>/<branch-name>` (`mkdir -p`
first). Copy the main checkout's gitignored `.env*` files in verbatim; leave
tracked templates alone. Skip if there are none. Never create, fill, or rotate
secrets.
