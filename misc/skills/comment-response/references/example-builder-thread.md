# Worked example: builder thread on a job-search tool

Input was pasted text: a Reddit post announcing `ApplyMind` (job application tracker, browser extension, Go backend, Next.js dashboard, AI match scoring), Enes's comment on it, and the OP's reply.

## The thread

Enes asked whether the match score changes what you apply to, or whether you start ignoring it after a few weeks, and mentioned he has been building a cover letter tool for about two years.

The OP answered: two jobs that reached interview both scored 8/10, he is unsure if the score is accurate or just his experience. He scores with a small model via async call, cheap. Preferences come from a fixed summary field in settings, so every job is scored against the same thing. He is considering switching to CV plus job description, but that costs more because the PDF has to be read.

## Analysis

- Actual question, inverted: he never answered whether the score changed his behaviour. He gave the number, not the decision.
- What he built: working tracker, one integration, cheap scoring path.
- What he already knows: cost of the PDF path, and that his preferences are fixed. Do not explain either back to him.
- Sharper point he missed: a fixed preference summary makes the score a constant across jobs. It filters ("am I roughly a fit") instead of ranking ("which of these is worth my evening"). Ranking is what makes a dashboard worth opening.
- Cost objection is smaller than he thinks: parse the CV once and cache the text per user. Each score then becomes one short call. The parse is the only real expense and it does not scale with job count.
- Only Enes can write: he has run CV parsing in production and hit the same wall from the other side.

Target type inferred: `personal-brand`. Peer thread, no offer, product already disclosed in his earlier comment so it needs no second mention.

## Handed over

Recommended:

> the fixed summary is the part I would question first. parse the cv once and cache the text, then each score is one short call. but with fixed preferences the score stays a fit check instead of a ranking, and the ranking is what makes a dashboard worth opening.

Alternative, softer, and it closes the loop on the question he skipped:

> 8/10 landing two interviews on a fixed summary is a decent signal, which is also why I would change the summary before the pdf parsing. caching the cv text makes the cost a rounding error. the fixed part is what stops it sorting your queue.

Handed over with: 260 and 240 chars, both PASS under `validate_replies.py`, no dashes, no links, nothing offered. The first one names the sharper problem, the second one stays closer to where he already is.
