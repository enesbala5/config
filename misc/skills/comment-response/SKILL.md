---
name: comment-response
description: Draft a reply in Enes's voice to a comment, post, or thread, from pasted text, a link, or a screenshot. Use when he asks for a comment reply, a Reddit/X/LinkedIn response, or "respond to this". Requires a target type (promote-coverlttr, personal-brand, help-only, lead-intent, network).
---

# Comment response

Turn a comment or thread into a reply Enes can paste as is. He supplies the material, you do the reading, analysis, and drafting. You never post anything.

## Input: three shapes

| Given | Do this |
| --- | --- |
| Pasted comment text | Separate who said what. The post body, his own comment, and the reply often arrive in one paste. His own words stay out of the draft; never hand them back to him. |
| Link to post or comment | Fetch it first with `web_extract`. Reddit blocks this class of host outright, plain permalinks and `.rss` variants both return 403 or an empty body, so when the fetch fails ask him to paste the text or send a screenshot instead of burning calls on retries. X links need the syndication endpoint (`cdn.syndication.twimg.com/tweet-result?id=<id>&lang=en&token=a`) or a browser. Search engines never work for this. |
| Screenshot | `vision_analyze` before anything else. Read author, subreddit or context, age, and vote count off the image, and re-crop to read small text. |

Verify the thread exists and is recent. Do not draft for a post you could not read.

## Target type is required

Infer it and state the pick in one line. Ask only when the goal is genuinely ambiguous. The target decides the shape: an excellent reply for one target is a failure for another.

| Target | Optimizes for | Product mention | Link | Soft offer |
| --- | --- | --- | --- | --- |
| `promote-coverlttr` | Coverlttr relevance inside a job search conversation | Allowed as "what I have been building", never by name in strict subs | Never | Only if he was asked for a tool |
| `personal-brand` | Builder and practitioner credibility | None | Never | Never |
| `help-only` | Being useful with zero commercial read | None | Never | Never |
| `lead-intent` | Someone openly asking for a tool or recommendation | Allowed, once | Never in text, the bio carries it | Yes, low pressure |
| `network` | Starting a relationship with one named person | Only if they asked | Never | Never |

Promo safety is per-channel. `help-only` is mandatory in `r/resumes`, `r/EngineeringResumes`, `r/cscareerquestions`, `r/jobs`, `r/recruiting`, `r/GetEmployed`, and `r/careerguidance`.

## Voice source

Fetch before drafting. Do not work from memory and do not guess at product facts.

```bash
gh api repos/enesbala5/portfolio/contents/misc/TONE.md -q .content | base64 -d
gh api repos/enesbala5/portfolio/contents/misc/PROFILE.md -q .content | base64 -d
gh api "repos/enesbala5/portfolio/contents/src/routes/work/(projects)/coverlttr/misc/summary.md" -q .content | base64 -d
```

Never use `misc/prompts/coverlttr-prompt.md`. It is an outdated invoicing draft, unrelated to the product.

Voice in short: earnest, slightly formal English with his own grammar shape left intact, concrete over adjectives, names and numbers and stack over claims, short sentences, one real question when he wants something back. No corporate polish, no growth-hacker cadence, no native-speaker smoothing.

## Hard rules

1. No em dashes or en dashes. Commas, or restructure the sentence.
2. No links and no bare domains in the text. The link lives in the bio. Offer to send it instead.
3. Short. Two or three sentences in a stranger's thread. A live technical exchange with another builder can run to about four, never longer.
4. Match the register he already used in that thread. Reddit comments run lowercase with minimal capitals and no headers, which is how his own comment reads. Sentence case is fine on LinkedIn and X.
5. No pitch, no feature list, no CTA.
6. Answer what the person actually said. Their question first, his angle second.
7. No overclaims. Never "ATS-proof", never "guaranteed interviews", never celebrating mass applying.
8. No invented metrics, clients, or wins. Every concrete claim traces to TONE.md, PROFILE.md, or the product summary.
9. Do not reuse an opener he already used in the same thread.

## Analysis before drafting

Write these down first. They decide the draft, so skipping them produces something generic.

- What is the actual question or claim, in their words?
- What did they build or try, and how far did they get?
- What do they already know? Explaining their own point back reads as condescending.
- Where is the honest disagreement, or the sharper thing they missed?
- What does the target type want out of this reply?
- Is there a line only Enes can write, from something he actually ran into? That line is the reply. Build around it.

If there is nothing real to add, say so instead of producing a filler comment.

## Output contract

One recommended reply, then one alternative that takes a different angle. For each: target type, char count, and one line on the angle. Plain text, copy-paste ready, no quotes around it, no markdown decoration, no hashtags.

Then the self-check:

- dashes, links, banned openers, length, terminal punctuation
- would a stranger read this as an ad
- is every concrete claim traceable to a real source

Mechanical check when the local Coverlttr tooling is present:

```bash
python3 /root/coverlttr-x/validate_replies.py --text "<draft>"
```

It enforces the dash, link, opener, and 260 character rules. Without it, do the same checks by eye. Where 260 is too tight for a technical exchange, keep the no-dash and no-link rules and say in the handover why the reply is longer.

## Pitfalls

- Drafting before reading the thread. A misread thread produces a reply that answers the wrong question, and it is obvious in the first line.
- Leading with "As someone who..." or "I built...". The other person comes first.
- Treating a builder thread as a lead. Someone showing their own project is a peer, not a prospect. Peer replies earn the profile click, an offer in that thread does the opposite.
- Repeating his previous comment back to them.
- Wrapping the reply in quotes or a code fence when handing it over. He pastes it straight in.
- Padding length in an exchange where they asked something technical. Two sentences that answer it beat four that circle it.

Worked example: [references/example-builder-thread.md](references/example-builder-thread.md)
