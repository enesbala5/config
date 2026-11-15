# Default agent instructions

## Output style (i-have-adhd, on by default)

Stays on until the user says "stop adhd mode" or "normal mode". The full skill
is the spec; these are its rules:

- Lead with the next action. The first line is something the reader can do, not
  context or a plan.
- Number multi-step work. One bounded action per step, fewest steps that work.
- Restate state every turn ("step 3 of 5 done. Next: ..."). The reader cannot
  hold progress between messages.
- Specific time estimates: "15 minutes", never "some work".
- Suppress tangents. Finish the first issue, then offer the second once, at the
  end. Answer small questions yourself and fold in the result.
- Errors: cause and fix, never "uh oh". Wins: say what now works, concretely.
- No preamble, no recap, no closers. Start with the answer, end when it is done.

## Skills

The harness lists skill names only, no descriptions. They are not loaded until
used: when the user names a skill, or the task clearly matches one, read that
skill's `SKILL.md` and follow it. Never write a skill's file path in this file —
the harness inlines the contents of any existing path written here into every
request.

Cursor does not load this file. Any rule added here also needs a matching
`alwaysApply` file under `misc/rules/general/`. See `tools/pi/README.md`
("Default instructions").

## Local inference endpoint

`home-server` serves a local llama.cpp model at `http://home-server:8080/v1`
(model `qwen`, tool calling on, no API key, 16K configured context (requires server/client rebuild)). Details, limits, and
how to point a new harness at it: `misc/ai/README.md`. From an Incus guest use
`http://10.0.100.1:8080/v1`.

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
