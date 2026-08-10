# Import a GNOME keyring dump into libsecret

Restore Freedesktop Secret Service items from a plaintext GNOME-style keyring
dump (the format under `~/.local/share/keyrings/*.keyring`, or a copy of that
file). Used when the session keyring was wiped / regenerated and you still have
a dump of the old contents.

```text
scripts/auth/keyring-import/
├── flake.nix                      # nix run / nix develop
├── import-keyring.py    # parser + secret-tool store
└── README.md                      # this guide
```

---

## Run (flake)

From this directory:

```bash
# Preview only (no writes; secrets shown as byte lengths)
nix run . -- --dry-run /path/to/Default.keyring

# Import into the default collection
nix run . -- /path/to/Default.keyring

# Import into a named keyring / collection
# (--keyring resolves label → D-Bus path; secret-tool aliases alone are not enough)
nix run . -- --keyring Test /path/to/Default.keyring

# Interactive shell with python3 + secret-tool on PATH
nix develop
python3 ./import-keyring.py --keyring Test /path/to/Default.keyring
```

From the repo root:

```bash
nix run ./scripts/auth/keyring-import -- --dry-run /path/to/Default.keyring
nix run ./scripts/auth/keyring-import -- --keyring Test /path/to/Default.keyring
```

The flake wraps the Python script with `python3`, `libsecret` (`secret-tool`),
and `busctl`. `--keyring NAME` resolves a collection **label** (or alias, or
full D-Bus path) to a path `secret-tool store --collection=…` accepts — bare
names are aliases to `secret-tool`, so `"Test"` must become
`/org/freedesktop/secrets/collection/Test`.

---

## Prerequisites

1. A running **Secret Service** (usually `gnome-keyring-daemon` unlocked for the
   graphical session). `secret-tool` talks to `org.freedesktop.secrets` on the
   session bus — not to a file by itself.
2. Flakes enabled (`nix run` / `experimental-features`).

Quick sanity check (after `nix develop`, or with `nix-shell -p libsecret`):

```bash
secret-tool search --all service Proton || true
```

If that errors with “Cannot autolaunch D-Bus” / “No such secret collection”,
unlock the login keyring from the desktop session (or log in graphically) and
retry.

---

## Dump format

The dump is INI-like. Metadata:

```ini
[keyring]
display-name=Default
ctime=...
mtime=...
lock-on-idle=false
lock-after=false
flags=1
```

Each secret is an integer section plus zero or more attribute sections:

```ini
[5]
item-type=0
display-name=zed-github-account
secret=THE_SECRET_VALUE_MAY_SPAN_LINES
mtime=...
ctime=...

[5:attribute0]
name=url
type=string
value=https://api.mistral.ai/v1

[5:attribute1]
name=username
type=string
value=Bearer
```

Notes:

- **`display-name`** → `secret-tool --label=...`
- **`secret=`** may be multiline (e.g. JSON with embedded PEM). The value
  continues until the next known key (`mtime=`, `ctime=`, …) or a new `[section]`.
- Attributes become `secret-tool` lookup keys. **At least one attribute is
  required** — that is how clients find the item later.
- `[keyring]` is ignored on import.
- Item numbers (`[5]`, `[6]`, …) are dump-local; the Secret Service assigns new
  paths on store.

Typical attribute patterns seen in this setup:

| Kind | Attributes |
| --- | --- |
| Zed / HTTP bearer tokens | `url`, `username=Bearer` |
| Chromium Safe Storage | `application=chromium`, `xdg:schema=chrome_libsecret_os_crypt_password_v2` |
| Chrome Safe Storage | `application=chrome`, `xdg:schema=chrome_libsecret_os_crypt_password_v2` |
| Python keyring (Proton) | `application=Python keyring library`, `service=Proton`, `username=...` |

---

## What the importer does

1. Parses every `[N]` item and its `[N:attributeM]` pairs.
2. Skips incomplete items (missing label/secret/attributes) with a stderr note.
3. For each item, runs the equivalent of:

   ```bash
   printf '%s' "$secret" | secret-tool store --label="$display_name" \
     attr1 value1 attr2 value2 ...
   ```

   Secret is passed on **stdin** so it does not appear in `ps` argv.

4. Prints a short summary (`imported N`, `failed M`).

Re-running the import for the same attributes **overwrites** the existing Secret
Service item (same lookup keys) — useful if a previous restore was partial.

---

## Manual restore (single item)

Same mechanism the script automates:

```bash
nix develop   # or: nix-shell -p libsecret

printf %s 'SECRET' | secret-tool store --label='zed-github-account' \
  url 'https://api.mistral.ai/v1' username 'Bearer'
```

Verify:

```bash
secret-tool search --all url https://api.mistral.ai/v1
```

---

## What we restored (2026-08-10)

After the login keyring was lost, these dump entries were written back with
`secret-tool`:

| Dump id | Label | Lookup attributes |
| --- | --- | --- |
| 5 | `zed-github-account` | `url=https://api.mistral.ai/v1`, `username=Bearer` |
| 6 | `zed-github-account` | `url=https://codestral.mistral.ai`, `username=Bearer` |
| 7 | `zed-github-account` | `url=https://api.deepseek.com/v1`, `username=Bearer` |
| 8 | `zed-github-account` | `url=https://generativelanguage.googleapis.com`, `username=Bearer` |
| 1 | `Chromium Safe Storage` | `application=chromium`, `xdg:schema=chrome_libsecret_os_crypt_password_v2` |
| 4 | `Chrome Safe Storage` | `application=chrome`, `xdg:schema=chrome_libsecret_os_crypt_password_v2` |
| 3 | `Password for 'proton-sso-accounts' on 'Proton'` | Python keyring / `service=Proton` / `username=proton-sso-accounts` |
| 2 | `Password for 'proton-sso-account-mvxgeni' on 'Proton'` | Python keyring / `service=Proton` / `username=proton-sso-account-mvxgeni` |

That session used ad-hoc `printf … \| secret-tool store …` inside
`nix-shell -p libsecret`. Prefer `nix run` against a dump file next time.

---

## Export / backup for next time

Keep a copy of the keyring file while it is still readable, e.g.:

```bash
# Common locations (names vary by desktop / keyring name)
ls -la ~/.local/share/keyrings/

cp -a ~/.local/share/keyrings/Default.keyring \
  ~/secure-backup/Default.keyring-$(date +%F)
```

Only the **plaintext / “file”** keyring format matches this importer. If the
file is encrypted binary, unlock/export via Seahorse (Passwords and Keys) or
keep backups of an already-decrypted dump. Do **not** commit dumps to this git
repo — they contain live secrets.

---

## Caveats

- **Chrome / Chromium Safe Storage**: restoring the old OSCrypt password only
  unlocks profile data encrypted with that key. If the browser already created
  a *new* Safe Storage secret after the wipe, overwriting it may break newly
  encrypted cookies/passwords while restoring access to older ones. Prefer
  restoring *before* launching the browser again when possible.
- **Proton VPN SSO JSON**: tokens and client certificates expire; a successful
  import may still require a fresh login if the session is stale.
- **API tokens in chat / tickets**: if a dump was pasted into a chat log,
  rotate those keys when practical.
- **Dry-run** does not print secret bodies — only lengths — to reduce accidental
  leak into scrollback.

---

## Troubleshooting

| Symptom | Likely fix |
| --- | --- |
| `secret-tool: command not found` | Use `nix run . -- …` or `nix develop` from this directory |
| D-Bus / “no secret service” | Unlock keyring in the GUI session; ensure `gnome-keyring` is running |
| Import “succeeds” but app still prompts | Attribute names/values must match what the app queries (compare with a working machine’s `secret-tool search --all …`) |
| Multiline Proton secret truncated | Use this importer (or ensure `secret=` continues until `mtime=` / next section); do not split on bare newlines by hand |
| Parser skips an item | Missing `display-name`, `secret`, or attributes — check that section in the dump |
