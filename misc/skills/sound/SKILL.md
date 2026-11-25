---
name: sound
description: Route a strategy for sound design and audio verification, not content request to the sound workspace. Picks one intent, then reads only that intent's entry file under <config>/misc/modules/sound/. Rules, gates and records live in the workspace, not here.
---

# sound

This skill only picks an intent and the one file to read next. Hard gates,
intent entries and lessons learned from real work live in `<config>/misc/modules/sound/`.
The evidence lives in `<config>/misc/guides/sound/`. Do not restate rules here, copy lesson
content, or invent a parallel process.

Resolve roots from the request, not from this file's directory depth:
`<config>` is the global home root (the verified config checkout for
global scope, the working repository for local scope). This router is
`<config>/misc/skills/sound/SKILL.md`; the workspace is `<config>/misc/modules/sound/`.
Per-project records live in `<repo>/misc/sound/` in the working repository; name that path, never link across roots.
Read the hard gates first, always: `<config>/misc/modules/sound/AGENTS.md`.

## Pick one intent

| The user wants | Intent | Read |
| --- | --- | --- |
| a specific sound made or built, or a catalogue answer read | **make** | `<config>/misc/modules/sound/intents/make/README.md` |
| an evidence-backed check of a sound, take, trim, mix or decision (read-only) | **verify** | `<config>/misc/modules/sound/intents/verify/README.md` |
| a film, motion-video clip or real-footage scene scored | **score** | `<config>/misc/modules/sound/intents/score/README.md` |
| to decide whether a moment gets sound, or what may be claimed about it | **place** | `<config>/misc/modules/sound/intents/place/README.md` |
| a provider, install, licence-policy or provenance question settled first | **setup** | `<config>/misc/modules/sound/intents/setup/README.md` |

Ambiguous between two intents → check `<config>/misc/modules/sound/README.md` for a record,
or ask once. Do not load a second intent's file for the same request. Do not
open guide lessons, stages or references until the intent file names them.
A **verify** intent, when present, is read-only and hands fixes to the change
intent.

Stop after naming the intent and reading its file. The intent file and
`<config>/misc/modules/sound/AGENTS.md` own the next step, including approval and any changes.
