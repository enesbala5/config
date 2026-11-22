# Intent: search-online

Research the web (and X where relevant), verify candidates by actually opening them, and present a ranked shortlist.

## Parameters

- `topic`, `dir` — common parameters.
- `count` — number of candidates, default 10.
- `focus` — optional emphasis, e.g. "anti-AI-slop visual design", "accessibility".

## Steps

1. Search the web for respected, high-quality sources on the topic. Include canonical/authoritative sites and, if the user wants, X threads or articles.
2. **Verify each candidate by fetching it** — a search snippet is not enough. Discard dead links, thin content and pieces that do not actually cover the topic.
3. Produce a shortlist of `count` entries in the guide's source table: title, author/publication, URL, and one line on why it is worth archiving. Prefer foundational pieces plus directly on-topic ones.
4. If a source cannot be fully read (login gate, paywall), label it as a lead and say what is missing.
5. Write or update the source table in `<dir>/README.md`, then **stop**. Emit a handoff with `status: awaiting_user` and the numbered list so the user can select.

## Do not

- Save any article yet — that is `save-online-source`.
- Continue the chain without the user's selection.
- Pad the list with weak sources to hit `count`; report fewer with a reason instead.
