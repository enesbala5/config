---
name: {{NAME}}
description: Route a {{PURPOSE}} request to the {{NAME}} workspace. Picks one intent, then reads only that intent's entry file under misc/{{NAME}}. Rules, gates and records live in the workspace, not here.
---

# {{NAME}}

This skill only picks an intent and the one file to read next. Hard gates,
intent entries and lessons learned from real work live in `misc/{{NAME}}/`.
The evidence lives in `{{GUIDE}}/`. Do not restate rules here, copy lesson
content, or invent a parallel process.

Resolve the repository from this skill's directory (three levels up). Run shell
commands from that root. Read the hard gates first, always:
`misc/{{NAME}}/AGENTS.md`.

## Pick one intent

| The user wants | Intent | Read |
| --- | --- | --- |
{{INTENT_ROWS}}

Ambiguous between two intents → check `misc/{{NAME}}/README.md` for a record,
or ask once. Do not load a second intent's file for the same request. Do not
open guide lessons, stages or references until the intent file names them.
A **verify** intent, when present, is read-only and hands fixes to the change
intent.

Stop after naming the intent and reading its file. The intent file and
`misc/{{NAME}}/AGENTS.md` own the next step, including approval and any changes.
