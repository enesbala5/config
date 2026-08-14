# Voice

Personal working-ticket voice. Same in every repo. Do not re-derive from
whatever issues happen to exist in the current repo.

Sources: GitHub issues `#19`, `#29`, `#30`, `#37`; `misc/notes/nixos.md`; Cursor
prompts; the `#40`–`#42` run that was accepted.

## How it sounds

- Spoken and compressed. One job per sentence. Filler is `like`, `eg.`, `etc.`, `seems like a pain`.
- First person when it's about you (`Dont want the same seagate errors`, `Prepare a list of rules that I can then import`).
- Concrete names, usually lowercase unless it's a proper product already capitalized: `home-server`, `seagate`, `telegram`, `restic`, `ActivityWatch`, `Nix`.
- `eg.` not `e.g.`. Ampersands in task lines (`Driver setup & declarative config`). Parentheticals for extra context (`(resurrect all not working properly)`, `(home-server)`, `(Hot Reload)`).
- Light mess is native: missing apostrophes (`Dont`), `occuring`, `typo-s`. Fine in the body. Not in the title.
- Nested `Tasks:` checkboxes. Occasional `>` aside under a task when something is annoying to use.
- Close comments stay tiny and lowercase-leading: `done, smartd is on and notifies via telegram`.

## Titles

- Title Case. Small words stay lowercase: `for`, `to`, `via`, `or`, `with`, `the`, `a`, `an`, `of`, `on`.
- Short imperative / noun phrase. Verbs: Setup, Add, Prepare, Fix, Configure, Refactor, Clean-up, Stabilize, Implement.
- Prefer `Setup` over `Set up`.
- No typos on the title. No `feat:` prefix.

## Bodies

**Shipped (will close):** 1–2 spoken sentences, taken from the user's prompts. No task list if it's done.

**Leftover (stay open):** brief description, blank line, then `Tasks:` with checkboxes.

**Cross-refs:** `Needed for #N` in the child body. Create the parent first so the number exists.

## Never

- `This issue tracks…` / `As discussed…` / `We should…`
- Marketing cadence, fake polish, or “no fluff”
- Re-deriving tone from the current repo's issues
- Padding the body past a couple of sentences plus tasks

## Gold-standard examples

### Shipped

```text
Setup smartd checks for home-server drives
Need smartd on home-server watching the disks (nvme, toshiba, seagate usb) and telegram when something pops up.
```

```text
Add smartd acknowledgment
Dont want the same seagate errors every time the server boots. Copy the error name from telegram and ack it on the box so it stays quiet.
```

```text
Add button support to telegram notify
Needed for #41. notify.sh should do buttons (copy / url) plus the usual md/html/plain, not a one-off script.
```

Close comments for those:

```text
done, smartd is on and notifies via telegram
done, ack file + copy button + acknowledge-smartd-error
done, --button copy|url on the global notify.sh
```

### Leftover

```text
Clean-up ActivityWatch buckets
Remove buckets for watchers that do not work properly, eg. the default window watcher
```

```text
Stabilize home server process management (PM2)

Tasks:

- [x] Resolve PM2 issue (resurrect all not working properly)
- [ ] Test PM2 startup (home-server)
```
