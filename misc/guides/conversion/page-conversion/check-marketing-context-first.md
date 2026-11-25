# Check product marketing context before auditing

**Feeds stage:** audit

If a `marketing/` or `docs/marketing/` directory exists, run `tree` over it to
find relevant files before asking questions or writing recommendations — this
applies as much to onboarding, activation and paywall/upgrade work as to a page
audit. Read
README/overview documents first, then open only the files crucial to the task;
do not try to read everything. For form work the equivalent context file is
`.agents/product-marketing.md` (`.claude/product-marketing.md` in older setups):
read it before asking for information it already covers.
