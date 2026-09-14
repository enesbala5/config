# TONE

Issue copy for this skill. Same in every repo. Do not re-derive from that
repo's issues. Do not use the `brand-voice` skill. Do not imitate chat
cadence, slang, or fake typos to "sound like" the author.

Sources (read these when unsure, not GitHub issues):

- `/home/e/dev/portfolio/misc/notes.txt`
- `/home/e/dev/portfolio/misc/prompts/`
- `/home/e/dev/portfolio/misc/reference/documentation/` (especially Artelia)

Those files are concrete and structured. Notes are short task lines with
names. Prompts use `eg.`, `&`, and file-level specifics. Docs state the
problem, the constraint, then the mechanism.

## How it sounds

- Clear, compressed, complete. One job per sentence or bullet.
- Facts and names, not personality. `restic`, `sqlite`, `hermes`,
  `home-server`, `Telegram`, `NixOS`.
- `eg.` is fine. Ampersands in lists (`UI & UX`) are fine.
- Parentheticals for extra context (`home-server`, `Hot Reload`).
- Correct spelling and apostrophes. No performed mess (`Dont`, `typo-s`,
  `doesnt`).
- First person only when the user's prompt actually used it.

## Titles

- Title Case. Small words stay lowercase: `for`, `to`, `via`, `or`,
  `with`, `the`, `a`, `an`, `of`, `on`.
- Short imperative or noun phrase. Verbs: Setup, Add, Prepare, Fix,
  Configure, Refactor, Clean-up, Stabilize, Implement.
- Prefer `Setup` over `Set up`.
- No typos on the title. No `feat:` prefix.

## Bodies

**Shipped (will close):** 1–2 sentences, or a short bullet list of what
landed. Taken from the user's prompts and the diff. No task list if it
is done.

**Leftover (stay open):** brief description, blank line, then `Tasks:`
with checkboxes.

**Cross-refs:** `Needed for #N` as the first sentence of the child body.
Create the parent first so the number exists.

## Never

- Slang or cartoon friction (`lose its mind`, `seems like a pain`)
- Intentional typos, dropped apostrophes, lowercase-leading sentences
  used as a style
- `This issue tracks…` / `As discussed…` / `We should…`
- Marketing cadence, "no fluff", or brand-voice tropes
- Re-deriving tone from the current repo's issues
- Padding past a couple of sentences plus tasks

## Gold-standard examples

### Shipped

```text
Setup smartd checks for home-server drives
Need smartd on home-server watching the disks (nvme, toshiba, seagate usb) and Telegram when a check fails.
```

```text
Add smartd acknowledgment
Avoid repeating the same seagate errors on every boot. Copy the error name from Telegram and ack it on the box so it stays quiet.
```

```text
Add button support to telegram notify
Needed for #41. notify.sh should support buttons (copy / url) plus the usual md/html/plain, not a one-off script.
```

```text
Isolate restic sqlite backups
Needed for #48. Dedicated restic secret, skip live sqlite, stable staging directory so restic snapshots stay consistent, and exclude hermes backup dumps from the other backup job.
```

Close comments for those:

```text
Done. smartd is on and notifies via Telegram.
Done. Ack file, copy button, and acknowledge-smartd-error.
Done. --button copy|url on the global notify.sh.
Done. Dedicated restic secret, sqlite skip, stable staging dir, hermes dumps excluded.
```

### Leftover

```text
Clean-up ActivityWatch buckets
Remove buckets for watchers that do not work properly, eg. the default window watcher.
```

```text
Stabilize home server process management (PM2)

Tasks:

- [x] Resolve PM2 issue (resurrect all not working properly)
- [ ] Test PM2 startup (home-server)
```
