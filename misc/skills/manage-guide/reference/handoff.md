# Handoff contract

Use the same block in both skills so a chain can switch from `manage-guide` to `manage-lesson` without translation.

```text
HANDOFF
skill: manage-guide | manage-lesson
intent: initialize-folder | search-online | save-online-source | status | verify | extract-from-guide | delete | enrich | audit
status: awaiting_user | ready | blocked | done
topic: <subject>
dir: <repo-relative guide directory>
params:
  <parameter>: <value>
artifacts:
  - <path or section written/updated>
next_intent: <skill / intent or none>
next_input:
  <key>: <value>
open_questions:
  - <question>            # omit when none
notes: <one line of context for the next agent>
```

## Rules

- `status: awaiting_user` is a hard stop. It is used by `search-online` (selection), and by `delete`/`enrich` when confirmation or the addition is needed.
- `status: blocked` always names the reason in `notes`; do not hand off a partial write as `ready`.
- `next_input` must contain everything the next agent needs, especially `selected` for `save-online-source` and `source` for `extract-from-guide`.
- `artifacts` lists written paths only; read-only intents list the report location or `none`.
- Keep it short — this block is prompt input for the next agent, not documentation.

## Launching the next subagent

```
You are executing `<skill> / <intent>` from the global skill of the same name.
Read that skill's SKILL.md and intents/<intent>.md fully before acting.
Inputs:
<paste HANDOFF block>
Work only inside <dir>. Do not commit.
Return a HANDOFF block when done.
```

When several articles are pending, reuse this with `extract-from-guide` and change only `next_input.source` each time. This reproduces the one-agent-per-article sequence the workflow was built from.
