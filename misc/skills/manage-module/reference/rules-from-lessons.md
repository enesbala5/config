# Turning lessons into rules

The guide is the evidence. The module is the **behavior**. Keep them separate.

## The distinction

- A **lesson** is one idea with its examples, in a guide bucket. It says what was learned and why.
- A **rule** is what must be true in the module's work. It is short, enforceable, and points at the lesson as evidence.

Never copy lesson prose into a rule file. Never put rule text into a lesson. A rule file may contain a pointer like:

```
Evidence: <guide>/<bucket>/<lesson-file>.md
```

Rules that cannot name a lesson are either new policy the user is choosing, or unsupported — say which.

## Derivation steps

1. Read the bucket READMEs and the relevant lessons.
2. Group lessons by the decision they affect (e.g. "before starting", "while building", "before finishing").
3. For each group, write the *must be true* statement. One rule per statement.
4. Compress: if two lessons produce the same rule, keep one rule with two evidence pointers.
5. Split: if one lesson produces several distinct rules, write several rules.
6. Mark each rule with its source bucket, not just a file — so a new lesson in that bucket is automatically relevant.
7. Drop anything that is really a workflow step; that belongs in an intent README, not in rules.

## Placement

| Kind of rule | Where |
|---|---|
| Always-on constraints, authority, approvals | Module `AGENTS.md` (hard gates only) |
| Domain constraints that apply within a stage | `pipeline/<stage>/README.md` |
| Many related domain rules | `rules/<set>/README.md`, indexed from `README.md` |
| A single check before finishing | The relevant intent's pre-ship section |

Keep `AGENTS.md` small. If it starts to read like a manual, move the detail into `rules/` and leave one gate bullet.

## Traceability contract

- Rule → lesson: by bucket path, stored next to the rule.
- Lesson → rule: not required. Guides stay unchanged and unaware of consumers.
- New lesson in an existing bucket: review the rules for that bucket once; usually no change needed.
- New bucket: decide whether it needs a stage, a rule set, or just an index line.

## Anti-patterns

- Copying a lesson into an intent file "for convenience" — creates two sources of truth.
- Writing rules that restate the guide's whole argument — rules must be actionable.
- Editing lessons to make them fit the module — forbidden.
- Rules with no evidence and no explicit user decision — delete them.
