---
name: marketing
description: Route marketing strategy work to the marketing module. Use when researching an audience or market, deciding positioning or claims, designing an offer or channel plan, sequencing a launch, designing experiments, or handing a strategy brief to copy or design. Picks one intent and reads only that intent's entry file under <config>/misc/modules/marketing/.
---

# marketing

This skill only picks an intent and the one file to read next. Hard gates,
intent entries and lessons learned from real work live in
`<config>/misc/modules/marketing/`. The evidence lives in
`<config>/misc/guides/marketing/`. Do not restate rules here, copy lesson content,
or invent a parallel process.

Resolve roots from the request, not from this file's directory depth:
`<config>` is the global home root (the verified config checkout for global
scope, the working repository for local scope). This router is
`<config>/misc/skills/marketing/SKILL.md`; the workspace is
`<config>/misc/modules/marketing/`. Per-project records live in
`<repo>/misc/marketing/` in the working repository; name that path, never link
across roots. Read the hard gates first, always:
`<config>/misc/modules/marketing/AGENTS.md`.

## Pick one intent

| The user wants | Intent | Read |
| --- | --- | --- |
| to gather audience, VOC, competitor or demand evidence before deciding | **research** | `<config>/misc/modules/marketing/intents/research/README.md` |
| to decide the problem, audience, category, angle, messaging or claims | **position** | `<config>/misc/modules/marketing/intents/position/README.md` |
| to build the offer, channel plan, launch sequence or test design | **plan** | `<config>/misc/modules/marketing/intents/plan/README.md` |
| to brief copy/design or enforce the strategy/execution boundary | **handoff** | `<config>/misc/modules/marketing/intents/handoff/README.md` |
| to audit a strategy artifact, claim set, plan or test — read-only | **verify** | `<config>/misc/modules/marketing/intents/verify/README.md` |

Ambiguous between two intents → check `<config>/misc/modules/marketing/README.md`
for a record, or ask once. Do not load a second intent's file for the same
request. Do not open guide lessons, stages or references until the intent file
names them. A **verify** intent, when present, is read-only and hands fixes to
the change intent.

Stop after naming the intent and reading its file. The intent file and
`<config>/misc/modules/marketing/AGENTS.md` own the next step, including approval
and any changes.
