# Intent: write

Owns new page and marketing copy from blank page; the trigger is a request to
draft copy, not to revise existing copy (`revise`), write social posts (`social`),
draft technical posts (`longform`) or check claims (`verify`).

## Read first

1. `<config>/misc/skills/copy/SKILL.md` — router; confirms `write` is the selected intent.
2. `<config>/misc/modules/copy/README.md` — module index.
3. `<config>/misc/modules/copy/AGENTS.md` — hard gates, records path and read-chain.
4. `<config>/misc/modules/copy/rules/README.md` — rules index.
5. `<config>/misc/modules/copy/rules/page-copy/README.md` — the rule set this intent applies.
6. The rule files named under `## Rules applied`, in that order. Do not load a whole lesson bucket or a sibling intent.

## Sequence

1. Ask the human for the five inputs: audience, traffic source, awareness stage, page format and the one primary action. If any is missing, ask once with 2–3 concrete options drawn from `<repo>` and stop; a one-line reply is enough.
2. Resolve the page format from the canonical page-type-by-awareness ladder for the confirmed problem. Do not pick a format by preference and do not reproduce the ladder's mapping in the deliverable.
3. Draft section by section under the rules listed below: confirm the awareness stage for this problem, choose the structure and headline, write the sections and CTA, then place risk reversal at the action point.
4. Save the inputs, format decision and rationale as a record in `<repo>/misc/copy/`; name that path, never a path across roots.
5. Deliver the copy with a rationale for each key choice, two or three alternatives per headline and CTA, and page title and meta description where relevant.

## Gates

- Hard gate: all five inputs are explicitly supplied by the human before any drafting. Research documents do not answer for them, and no input is inferred, assumed or worked around. A missing input means ask once, then stop.
- The awareness stage must be confirmed for the specific problem this page addresses before the page format is derived; a reader label or a research doc for another problem does not count.
- Drafting changes nothing outside this intent's scope: no guide lessons, module gates or sibling-intent files are edited.
- Approval: the Authority and Approval fields in `<config>/misc/modules/copy/AGENTS.md` are unset, so no default approver is assumed. Obtain explicit user sign-off on the five inputs before drafting and on the final draft before it counts as done.

## Rules applied

- `<config>/misc/modules/copy/rules/page-copy/five-inputs-before-page-copy.md`
- `<config>/misc/modules/copy/rules/page-copy/awareness-scoped-to-problem.md`
- `<config>/misc/modules/copy/rules/page-copy/page-format-from-awareness-ladder.md`
- `<config>/misc/modules/copy/rules/page-copy/advertorial-outer-arc-for-unaware.md`
- `<config>/misc/modules/copy/rules/page-copy/specific-claims-over-vague.md`
- `<config>/misc/modules/copy/rules/page-copy/benefits-lead-features.md`
- `<config>/misc/modules/copy/rules/page-copy/mirror-customer-language.md`
- `<config>/misc/modules/copy/rules/page-copy/lead-with-reader-outcome.md`
- `<config>/misc/modules/copy/rules/page-copy/cta-action-verb-plus-outcome.md`
- `<config>/misc/modules/copy/rules/page-copy/cta-visible-and-clear.md`
- `<config>/misc/modules/copy/rules/page-copy/risk-reversal-at-action-point.md`
- `<config>/misc/modules/copy/rules/page-copy/headline-matched-to-message.md`
- `<config>/misc/modules/copy/rules/page-copy/narrative-over-feature-list.md`
- `<config>/misc/modules/copy/rules/page-copy/how-it-works-numbered-outcome-steps.md`
- `<config>/misc/modules/copy/rules/page-copy/testimonials-specific-results.md`
- `<config>/misc/modules/copy/rules/page-copy/one-idea-per-section.md`
- `<config>/misc/modules/copy/rules/page-copy/reader-addressed-voice.md`
- `<config>/misc/modules/copy/rules/page-copy/deliver-alternatives-and-annotations.md`
- `<config>/misc/modules/copy/rules/page-copy/make-the-pain-felt.md`

## Handoff

- On success → done; the copy and its decision record stay in `<repo>/misc/copy/`.
- On a missing or disputed input, or missing approval → hand back to the user for the input or sign-off before any drafting continues.
- On a request to improve existing copy, produce social posts, longform or claim checking → hand back to the router to select the matching sibling intent; do not do that work here.

## Never

- Never draft copy, a brief or a strategy with an input missing, and never infer one from research or from the reader's label.
- Never choose page format by preference, or default to a landing page or quiz for unaware traffic.
- Never invent numbers, quotes or testimonials, and never ship a claim that cannot be made specific.
- Never restate the canonical ladder's mapping in the copy or in the deliverable's rationale.
- Never edit guide lessons, module hard gates or a sibling intent from this intent.
