---
name: copy
description: Route copy work to the global copy module. Use when writing or rewriting marketing page copy, editing or refreshing existing copy, drafting X posts or comment replies, or drafting technical how-to blog posts. Picks one intent, then reads only that intent's entry file under <config>/misc/modules/copy/. Rules, gates and records live in the workspace, not here.
---

# copy

This skill only picks an intent and the one file to read next. Hard gates,
intent entries and lessons learned from real work live in `<config>/misc/modules/copy/`.
The evidence lives in `<config>/misc/guides/copy/`. Do not restate rules here, copy lesson
content, or invent a parallel process.

Resolve roots from the request, not from this file's directory depth:
`<config>` is the global home root (the verified config checkout for
global scope, the working repository for local scope). This router is
`<config>/misc/skills/copy/SKILL.md`; the workspace is `<config>/misc/modules/copy/`.
Per-project records live in `<repo>/misc/copy/` in the working repository; name that path, never link across roots.
Read the hard gates first, always: `<config>/misc/modules/copy/AGENTS.md`.

## Pick one intent

| The user wants | Intent | Read |
| --- | --- | --- |
| to draft new copy or copy-led content | **write** | `<config>/misc/modules/copy/intents/write/README.md` |
| to change, polish or continue existing work | **revise** | `<config>/misc/modules/copy/intents/revise/README.md` |
| to draft X posts or comment replies | **social** | `<config>/misc/modules/copy/intents/social/README.md` |
| to draft, outline or rewrite a long article | **longform** | `<config>/misc/modules/copy/intents/longform/README.md` |
| to check or audit, including pre-ship checks | **verify** | `<config>/misc/modules/copy/intents/verify/README.md` |

Ambiguous between two intents → check `<config>/misc/modules/copy/README.md` for a record,
or ask once. Do not load a second intent's file for the same request. Do not
open guide lessons, stages or references until the intent file names them.
A **verify** intent, when present, is read-only and hands fixes to the change
intent.

Stop after naming the intent and reading its file. The intent file and
`<config>/misc/modules/copy/AGENTS.md` own the next step, including approval and any changes.
