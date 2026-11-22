# The full process (worked example)

This is the workflow these two skills were extracted from: building an evidence-backed web-design guide in the Coverlttr repository from scratch, then turning its articles into lessons. Use it as the canonical sequence when the user asks for "the whole workflow".

## Origin: the three requests

1. **Scaffold + research.** The user pointed at an existing guide (`misc/guides/ugc/`) and asked for a similar setup at `misc/guides/design/web/` with `misc/sources/` inside it for Markdown copies of articles found online and on X. They asked for a list of about ten highly respected articles first, said they would select which ones to keep, and only then wanted articles saved as MD and learnings extracted into a design pipeline/skills. Browser automation was allowed if needed.
2. **Archive.** After selection, they asked for the two extra X leads to be included too, and for every source to be fetched into `misc/sources/` as MD — X posts as MD/plaintext — converting HTML to MD where needed.
3. **Extract.** They asked for subagents, one after the other, each opening one article, extracting lessons into buckets organised by part of the design process (like the UGC guide's directories), with an explicit rule: do not duplicate an existing lesson — enrich it if it makes sense. A follow-up decision made lessons standalone (no `Source:` line back to the article).

## Sequence

```
manage-guide  initialize-folder [topic] [dir] [based-on?]
manage-guide  search-online     [topic] [dir] [count?] [focus?]
        >>> USER GATE: user selects sources <<<
manage-guide  save-online-source [topic] [dir] [selected]
manage-guide  verify             [topic] [dir]
manage-lesson  extract-from-guide [topic] [dir] [source]   <- repeat, sequentially, once per source
manage-lesson  audit              [topic] [dir]
```

There is no separate `finalize` step. Routing from stages to lessons is owned by the consuming workspace (in Coverlttr, `misc/design/pipeline/`), not by the guide.

## Why the gates and ordering matter

- `initialize-folder` reads an existing guide first so the new guide inherits conventions instead of inventing them.
- `search-online` verifies candidates by opening them; a snippet is not evidence. It stops for the user's selection — never auto-advance.
- `save-online-source` archives verbatim, so extraction later has a stable source of truth.
- Sequential extraction matters: each agent reads the buckets as the previous agents left them. That is what makes enrich-not-duplicate work across agents. Running them in parallel would create duplicates.
- `audit` is last because only then are all lessons present.

## Handoff-driven subagents

Each step emits a [`handoff`](handoff.md) block. The next agent is launched with that block as its input plus a short prompt naming the skill and intent. The prompt pattern:

```
You are executing `<skill> / <intent>` from the global skill of the same name.
Read that skill's SKILL.md and intents/<intent>.md fully before acting.
Inputs: <handoff block>
Work only inside <dir>. Do not commit.
Return a handoff block when done.
```

`status: awaiting_user` means stop the chain. `status: ready` means the orchestrator may launch the next intent.
