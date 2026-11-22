# Intent: initialize

Build one new module from a guide. Do not scaffold before the design is approved.

## Parameters

- `name`, `repo`, `guide`, `purpose` — common parameters; prompt interactively if missing.
- `intents` — the approved intent list. Propose 3–5 from the purpose and buckets; include a read-only `verify` for any module that changes artifacts.
- `layers` — optional layers from [`../reference/module-anatomy.md`](../reference/module-anatomy.md), only those justified.
- `stages` — stage names, needed only when the `pipeline` layer is chosen.
- `wiring` — whether to touch the repo's root `AGENTS.md`, root `README.md`, and a Consumers pointer in the guide README. Default yes for the first two; ask for the guide file.

## 1. Study the evidence

Read the guide's top-level README, each bucket README, and only the lessons needed to understand the domain range. Never read every lesson, never edit the guide. Record the bucket names verbatim — they become routing targets.

## 2. Propose the design

Present one short block: intents with reasons, layers (and deliberate omissions), hard gates derived from the guide's strongest warnings, 2–4 suggestions from [`../reference/flexibility.md`](../reference/flexibility.md), and the wiring plan. Then **stop** for approval.

## 3. Scaffold

```sh
node <skill>/scripts/scaffold-module.js <repo> <name> \
  --dir misc/<name> --intents <csv> --layers <csv> \
  --stages <csv> --guide <guide> --purpose <phrase>
```

The script writes only the workspace skeleton from this skill's templates. It never writes `.agents/skills/<name>/SKILL.md`.

## 4. Fill the files

- `AGENTS.md`: hard gates, record locations, read-chain. Keep it short.
- `README.md`: index of intents and layers; where rules live.
- Each `intents/<intent>/README.md`: trigger, sequence, gates, handoff.
- `pipeline/README.md`: stage → guide-bucket table, no lesson content.
- `LEARNINGS.md`: status vocabulary and empty sections.
- Rule files: see [`../reference/rules-from-lessons.md`](../reference/rules-from-lessons.md).

Use the approved intent names exactly — the verifier checks router rows against these folders.

## 5. Hand off the router

```sh
node <skill>/scripts/scaffold-module.js <repo> <name> --print-router \
  --dir misc/<name> --intents <csv> --guide <guide> --purpose <phrase>
```

Pass the rendered router to `manage-skill` with **local scope** in `<repo>`, quoting the full router in the handoff so that skill never reads this folder. Include the [`../reference/handoff.md`](../reference/handoff.md) block.

If `manage-skill` is unavailable: write the router from [`../templates/skill-router.md`](../templates/skill-router.md) yourself and report that delegation did not happen.

## 6. Wire and verify

Apply approved discovery edits, then run `node <skill>/scripts/verify-module.js <repo> <name>`. Fix every problem and re-run. Report files created, decisions, and what was deferred.
