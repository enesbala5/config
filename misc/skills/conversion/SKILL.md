---
name: conversion
description: Route conversion work — audits of pages, onboarding or paywalls, lifecycle email sequence plans, and read-only verification — to the conversion workspace. Picks one intent, then reads only that intent's entry file under <config>/misc/modules/conversion/. Rules, gates and records live in the workspace, not here.
---

# conversion

This skill only picks an intent and the one file to read next. Hard gates,
intent entries and lessons learned from real work live in `<config>/misc/modules/conversion/`.
The evidence lives in `<config>/misc/guides/conversion/`. Do not restate rules here, copy lesson
content, or invent a parallel process.

Resolve roots from the request, not from this file's directory depth:
`<config>` is the global home root (the verified config checkout for
global scope, the working repository for local scope). This router is
`<config>/misc/skills/conversion/SKILL.md`; the workspace is `<config>/misc/modules/conversion/`.
Per-project records live in `<repo>/misc/conversion/` in the working repository; name that path, never link across roots.
Read the hard gates first, always: `<config>/misc/modules/conversion/AGENTS.md`.

## Pick one intent

| The user wants | Intent | Read |
| --- | --- | --- |
| to audit a page, form, onboarding step, paywall or email flow | **audit** | `<config>/misc/modules/conversion/intents/audit/README.md` |
| to design a fix, flow, checklist, upgrade moment or email sequence | **plan** | `<config>/misc/modules/conversion/intents/plan/README.md` |
| to check an audit or plan against the gates (read-only) | **verify** | `<config>/misc/modules/conversion/intents/verify/README.md` |

Ambiguous between two intents → check `<config>/misc/modules/conversion/README.md` for a record,
or ask once. Do not load a second intent's file for the same request. Do not
open guide lessons, stages or references until the intent file names them.
A **verify** intent, when present, is read-only and hands fixes to the change
intent.

Stop after naming the intent and reading its file. The intent file and
`<config>/misc/modules/conversion/AGENTS.md` own the next step, including approval and any changes.
