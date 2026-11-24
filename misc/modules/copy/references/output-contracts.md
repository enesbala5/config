# Output contracts

Shapes an intent hands to the human. These are formats, not workflow rules;
each intent owns its sequence and gates.

## Page copy (`write`)

Organised by section: headline, subheadline, primary CTA, section headers and
body, secondary CTAs. Annotations explain key choices; headlines and CTAs get
2–3 alternatives with a rationale. Meta title and description when relevant.
No page until the five awareness inputs are explicitly confirmed.

## Edit review (`revise`)

For each focused pass: what was found, why it is an issue, and a specific
proposed edit. The author makes the final decision. A refresh records whether
the decision was refresh or rewrite. High-stakes copy shows the expert-panel
scores and the lowest-scoring areas addressed first.

## X batch (`social`)

A Telegram-ready message, nothing around it:

```
X posts, 4 options

1. personal, <account>
from: <source>
<draft>
(<n> chars)

2. personal, <account>
from: <source>
<draft>
(<n> chars)

3. coverlttr, <account>
voice: <register>, from: <source>
<draft>
(<n> chars)

4. coverlttr, <account>
voice: <register>, from: <source>
<draft>
(<n> chars)
```

Plain text, copy-paste ready: no quotes, markdown decoration or code fence.
One `from:` line per option, a few words. The ledger is the only archive.

## Comment reply (`social`)

One recommended reply, then one alternative taking a different angle. Each
carries the target type, character count and one line on the angle. Plain text,
no quotes, no markdown decoration, no hashtags. Then the self-check, including
the anti-AI pass.

## Technical post (`longform`)

Frontmatter matching the portfolio contract, then body headings starting at
`# Introduction` (the page title comes from frontmatter). Main Challenge,
Solution, Process Walkthrough, Putting It Together, Conclusion. Callouts carry
constraints and credits; code blocks are fenced with a language and context
above. No generated image assets — frontmatter points at expected paths and the
human adds the files.

## Verify report (`verify`)

Read-only findings as `file:line` plus the failed check and the owning intent.
No edits, no fixes applied. Hand fixes to `write`, `revise`, `social` or
`longform` as appropriate.
