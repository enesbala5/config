---
name: design
description: Route design requests to the working repository's design workflow. Use for a new page, screen, component or landing page, an existing design change, a read-only interface critique or audit, or a study of a reference site or screenshot.
---

# Design

Resolve `<config>` from this skill's canonical location at
`<config>/misc/skills/design/SKILL.md` (follow installed symlinks). Read
`<config>/misc/modules/design/README.md` and its routing gates. The project
root is separate from the skill location; resolve it as described in the gates.

Pick one intent, then open only its entry:

| The user wants | Intent | Read |
| --- | --- | --- |
| A new page, screen, component or landing page | make | `<config>/misc/modules/design/intents/make/README.md` |
| To change, restyle or continue an existing design | revise | `<config>/misc/modules/design/intents/revise/README.md` |
| To check, critique or audit an interface | verify | `<config>/misc/modules/design/intents/verify/README.md` |
| To study a reference and capture reusable principles | study | `<config>/misc/modules/design/intents/study/README.md` |

Honor an explicit intent. If the request does not identify one intent, ask
once. Name the selected intent and follow its handoff; do not open a second
intent or implement from this router.
