# Five read-only critics propose; one fixer applies

**Feeds stage:** film-sound

Critique runs five read-only agents in parallel, one lens each: sync, edges, masking, tonal, director. Each tests its own proposed fixes as a variant in its own folder (`variant.py --ops ... --render --qa`) and returns ranked issues with exact operations and before -> after numbers; none edits the shared design. Then ONE fixer merges the operations, resolves conflicts, checks the merged variant against the previous `qa.json`, applies it with `variant.py --apply` (originals backed up) and requires no QA regression. Acknowledge a confirmed deliberate exception with `"qa_ok": "<reason>"`. Run at least one round; run a second when levels or the music edit changed.
