# Mine the referenced repo for the storyline

**Feeds stage:** longform

A referenced git repo is a receipt source, not a link to paste. Resolve it from
the path the user actually pointed at (`git -C <path> rev-parse --show-toplevel`),
even when that folder is a nested checkout — do not assume the workspace repo,
and do not SSH to a remote host to read history.

Mine before outlining: `git log --follow` for each referenced path, `git show
--stat` on mechanism-looking commits to find sibling files, and `--grep` / path
globs only when paths are still unknown. Cap the log, read patches only for the
shortlisted commits, and ignore rebuild/generation noise.

Cluster commits into beats, oldest first: first landing → failed or reverted
approach → constraint → required mechanism → later polish. Use those beats to
fill Introduction (the painful part), Main Challenge, callouts, and the
optional-vs-required split in Conclusion. A terse commit message is only a hint;
the diff decides what counts. If history disagrees with what the user said, ask
rather than silently overriding it.
