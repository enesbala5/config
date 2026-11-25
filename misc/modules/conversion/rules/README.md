# Rules

What must be true when using this module. Each rule points to lesson evidence in
`<config>/misc/guides/conversion/`. Rules never copy lesson prose; lessons never
change to fit rules.

## Sets

- `diagnosis` — what must be true before recommending a change;
  `<config>/misc/modules/conversion/rules/diagnosis/README.md`
- `design` — constraints while designing a surface or sequence;
  `<config>/misc/modules/conversion/rules/design/README.md`
- `verification` — checks before accepting a test or claim;
  `<config>/misc/modules/conversion/rules/verification/README.md`

## Conventions

- One enforceable statement per rule.
- Always include `Evidence: <config>/misc/guides/conversion/<bucket>/<lesson>.md`
  (more than one Evidence line when several lessons support the same rule).
- If no lesson supports a rule, mark it as a user decision instead of inventing
  evidence. The eight hard gates in
  `<config>/misc/modules/conversion/AGENTS.md` are approved module policy and do
  not need lesson evidence here.
