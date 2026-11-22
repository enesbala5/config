# Handoff blocks

Use the same compact block between intents and between skills. It is prompt input for the next agent, not documentation.

```text
HANDOFF
skill: manage-module | manage-skill
intent: initialize | extend | suggest | verify | create-skill
status: awaiting_approval | ready | blocked | done
name: <module name>
repo: <repository path or identifier>
dir: misc/<name>
guide: <repo-relative guide path>
design:
  intents: [make, revise, verify, study]
  layers: [pipeline, projects]
  gates: [one line each]
  suggestions: [accepted ones]
artifacts:
  - <path written>
next_intent: <skill / intent or none>
next_input:
  router: <rendered router markdown, quoted in full when next is manage-skill>
  target: <extend target, when next is extend>
open_questions:
  - <question>          # omit when none
notes: <one line of context>
```

## Rules

- `awaiting_approval` is a hard stop: never scaffold before the design is approved.
- `ready` means the next agent may act. `blocked` always names the reason in `notes`.
- When handing the router to `manage-skill`, quote the **full rendered router** inside `next_input.router` so that skill never needs to read this folder. State **local scope** explicitly, plus the target repo and the requirement that `name` matches the router folder.
- `verify` hands problems to `extend` with `next_input.target` set.
- Keep it short; verbose handoffs defeat progressive disclosure.

## Chain position

```
manage-guide -> manage-lesson -> manage-module -> manage-skill
   sources         lessons         rules/module     router + portability gate
```

This skill consumes lessons and produces a workspace. It does not create source archives, extract lessons, or own skill-format mechanics.
