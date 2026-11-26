# Design routing gates

- Resolve `<repo>` with `git rev-parse --show-toplevel` from the directory
  where the user wants the work done, not from the skill or config directory.
  If no project root resolves, ask for the project directory and stop.
- Look only in that repository for `<repo>/misc/design/README.md`. If it is
  missing, report that no design entry was found and ask for the repository's
  workflow path. Stop the handoff; do not scaffold a workspace, borrow another
  repository's rules, or fall back to the config checkout as the project.
- Pass one intent and the original request to the repository entry. The local
  workflow owns its rules, approvals, and records. Follow its local docs
  directly; do not re-invoke the global skill or follow an entry that points
  back to it. If the entry cannot handle the intent, report that and stop.
