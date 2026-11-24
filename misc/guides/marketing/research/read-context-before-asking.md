# Read existing product-marketing context before asking questions

**Feeds stage:** research

If a product-marketing context file exists (`.agents/product-marketing.md`,
`.claude/product-marketing.md`, or the legacy `product-marketing-context.md`),
read it before asking the user anything. Use it to skip questions already
answered. Only ask for what the context file does not cover.

If a `marketing/` or `docs/marketing/` directory exists, run `tree` to locate
relevant files, then read the README/overview documents first and open only the
files crucial to the task — do not try to read every file in the directory.
