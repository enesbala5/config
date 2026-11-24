# Rules

What must be true when using this module. Each rule points to lesson evidence in
`<config>/misc/guides/copy/`. Rules never copy lesson prose; lessons never change to fit rules.

## Sets

- `page-copy` — `<config>/misc/modules/copy/rules/page-copy/README.md`. Web and marketing page copy: awareness inputs, structure, headline, CTA. Used by `write`.
- `editing` — `<config>/misc/modules/copy/rules/editing/README.md`. Focused passes, author ownership, high-stakes gate, content refresh. Used by `revise`.
- `social` — `<config>/misc/modules/copy/rules/social/README.md`. X batches and comment replies: voice registers, traceability, format bans, dedupe. Used by `social`.
- `longform` — `<config>/misc/modules/copy/rules/longform/README.md`. Technical how-to posts: receipts, git storyline, skeleton, voice, frontmatter. Used by `longform`.
- `cross-cutting` — `<config>/misc/modules/copy/rules/cross-cutting/README.md`. No-fabrication and voice sourcing across every output. Used by `verify`.

## Conventions

- One enforceable statement per rule.
- Always include `Evidence: <config>/misc/guides/copy/<bucket>/<lesson>.md` (bucket path is enough
  when several lessons support the same rule). Compress duplicates into one rule with several
  evidence pointers.
- If no lesson supports a rule, mark it as a user decision instead of inventing evidence. The
  one such rule is `<config>/misc/modules/copy/rules/social/drafts-only-never-publish.md`.
- Workflow steps live in intents, not here. Nested files add or override; they never restate an
  ancestor.
