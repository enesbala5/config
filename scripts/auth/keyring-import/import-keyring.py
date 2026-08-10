#!/usr/bin/env python3
"""Import a GNOME-style keyring dump into the Freedesktop Secret Service.

Usage:
  import-keyring [--dry-run] [--keyring NAME] <dump-file>

See README.md in this directory.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


SECTION_RE = re.compile(r"^\[(.+)\]\s*$")
META_KEY_RE = re.compile(
    r"^(item-type|display-name|secret|mtime|ctime|lock-on-idle|lock-after|flags)="
)


def parse_dump(path: Path) -> list[dict]:
    """Return list of {label, secret, attrs: [(name, value), ...]}."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()

    items: dict[str, dict] = {}
    attributes: dict[str, list[dict]] = {}
    order: list[str] = []
    current: tuple | None = None
    secret_cont: str | None = None

    def ensure_item(iid: str) -> None:
        if iid not in items:
            items[iid] = {"display-name": None, "secret": None}
            attributes[iid] = []
            order.append(iid)

    i = 0
    while i < len(lines):
        line = lines[i]

        if secret_cont is not None:
            if SECTION_RE.match(line) or META_KEY_RE.match(line):
                secret_cont = None
                continue
            items[secret_cont]["secret"] += "\n" + line
            i += 1
            continue

        m = SECTION_RE.match(line)
        if m:
            name = m.group(1)
            if name == "keyring":
                current = ("keyring", None, None)
            elif re.fullmatch(r"\d+", name):
                ensure_item(name)
                current = ("item", name, None)
            elif re.fullmatch(r"\d+:attribute\d+", name):
                iid = name.split(":", 1)[0]
                ensure_item(iid)
                attributes[iid].append({"name": None, "value": None})
                current = ("attr", iid, len(attributes[iid]) - 1)
            else:
                current = None
            i += 1
            continue

        if current is None or current[0] == "keyring":
            i += 1
            continue

        if current[0] == "item":
            iid = current[1]
            if line.startswith("display-name="):
                items[iid]["display-name"] = line[len("display-name=") :]
            elif line.startswith("secret="):
                items[iid]["secret"] = line[len("secret=") :]
                secret_cont = iid
            i += 1
            continue

        if current[0] == "attr":
            iid, aidx = current[1], current[2]
            if line.startswith("name="):
                attributes[iid][aidx]["name"] = line[len("name=") :]
            elif line.startswith("value="):
                attributes[iid][aidx]["value"] = line[len("value=") :]
            i += 1
            continue

        i += 1

    result: list[dict] = []
    for iid in order:
        it = items[iid]
        label = it["display-name"]
        secret = it["secret"]
        if label is None or secret is None:
            print(
                f"skip item [{iid}]: missing display-name or secret",
                file=sys.stderr,
            )
            continue
        attrs = [
            (a["name"], a["value"])
            for a in attributes.get(iid, [])
            if a["name"] is not None and a["value"] is not None
        ]
        if not attrs:
            print(
                f"skip item [{iid}] ({label!r}): no attributes "
                "(secret-tool needs at least one)",
                file=sys.stderr,
            )
            continue
        result.append({"id": iid, "label": label, "secret": secret, "attrs": attrs})
    return result


def _busctl(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["busctl", "--user", *args],
        check=False,
        capture_output=True,
        text=True,
    )


def _parse_object_path(busctl_stdout: str) -> str | None:
    # e.g. 'o "/org/freedesktop/secrets/collection/Test"\n'
    text = busctl_stdout.strip()
    if text.startswith('o "'):
        return text[3:-1] if text.endswith('"') else text[2:].strip().strip('"')
    if text.startswith("o "):
        return text[2:].strip().strip('"')
    return None


def _parse_string(busctl_stdout: str) -> str | None:
    # e.g. 's "Test"\n'
    text = busctl_stdout.strip()
    if text.startswith('s "'):
        return text[3:-1] if text.endswith('"') else None
    if text == 's ""':
        return ""
    return None


def resolve_collection(name: str) -> str:
    """Map a keyring label/name to a value secret-tool --collection accepts.

    secret-tool treats bare names as *aliases* (/org/freedesktop/secrets/aliases/X).
    GNOME keyrings like "Test" are usually collections, not aliases — pass the
    D-Bus object path instead.
    """
    if name.startswith("/"):
        return name

    if not shutil.which("busctl"):
        # Best-effort: collection object path (works for simple names like Test)
        return f"/org/freedesktop/secrets/collection/{name}"

    # Alias (e.g. default, session)
    alias = _busctl(
        "call",
        "org.freedesktop.secrets",
        "/org/freedesktop/secrets",
        "org.freedesktop.Secret.Service",
        "ReadAlias",
        "s",
        name,
    )
    if alias.returncode == 0:
        path = _parse_object_path(alias.stdout)
        if path and path != "/":
            return path

    # Direct collection path
    direct = f"/org/freedesktop/secrets/collection/{name}"
    label_prop = _busctl(
        "get-property",
        "org.freedesktop.secrets",
        direct,
        "org.freedesktop.Secret.Collection",
        "Label",
    )
    if label_prop.returncode == 0:
        return direct

    # Match by Label across all collections
    cols = _busctl(
        "get-property",
        "org.freedesktop.secrets",
        "/org/freedesktop/secrets",
        "org.freedesktop.Secret.Service",
        "Collections",
    )
    if cols.returncode != 0:
        print(
            f"Could not list Secret Service collections while resolving {name!r}:\n"
            f"{cols.stderr.strip()}",
            file=sys.stderr,
        )
        raise SystemExit(1)

    # ao 3 "/path1" "/path2" ...
    paths = re.findall(r'"([^"]+)"', cols.stdout)
    for path in paths:
        lab = _busctl(
            "get-property",
            "org.freedesktop.secrets",
            path,
            "org.freedesktop.Secret.Collection",
            "Label",
        )
        if lab.returncode == 0 and _parse_string(lab.stdout) == name:
            return path

    print(
        f"No keyring/collection named {name!r}.\n"
        "Tip: `busctl --user get-property org.freedesktop.secrets "
        "/org/freedesktop/secrets org.freedesktop.Secret.Service Collections`",
        file=sys.stderr,
    )
    raise SystemExit(1)


def store_item(
    label: str,
    attrs: list[tuple[str, str]],
    secret: str,
    *,
    collection: str | None,
) -> None:
    if not shutil.which("secret-tool"):
        print(
            "secret-tool not found on PATH. Run via: nix run . -- <dump-file>",
            file=sys.stderr,
        )
        raise SystemExit(1)

    cmd = ["secret-tool", "store", f"--label={label}"]
    if collection:
        cmd.append(f"--collection={collection}")
    for name, value in attrs:
        cmd.extend([name, value])
    # Secret on stdin — never in argv / process list
    subprocess.run(cmd, input=secret.encode("utf-8"), check=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Import GNOME keyring dump items into libsecret via secret-tool."
    )
    parser.add_argument("dump_file", type=Path, help="Path to *.keyring dump file")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and list items; do not write to the keyring",
    )
    parser.add_argument(
        "--keyring",
        metavar="NAME",
        help="Target keyring label or collection path (resolved for secret-tool)",
    )
    args = parser.parse_args()

    if not args.dump_file.is_file():
        print(f"Dump file not found: {args.dump_file}", file=sys.stderr)
        return 1

    collection: str | None = None
    if args.keyring:
        collection = resolve_collection(args.keyring)

    records = parse_dump(args.dump_file)
    if args.dry_run:
        if args.keyring:
            print(f"target keyring: {args.keyring}")
            if collection:
                print(f"resolved collection: {collection}")
        for rec in records:
            print("---")
            print(f"label: {rec['label']}")
            print("attributes:")
            for name, value in rec["attrs"]:
                print(f"  {name}={value}")
            print(f"secret: <{len(rec['secret'].encode('utf-8'))} bytes>")
        print(f"Dry-run: would import {len(records)} item(s) from {args.dump_file}")
        return 0

    if collection:
        print(f"Using collection: {collection}")

    imported = 0
    failed = 0
    for rec in records:
        print(f"Storing: {rec['label']}")
        try:
            store_item(
                rec["label"],
                rec["attrs"],
                rec["secret"],
                collection=collection,
            )
            imported += 1
        except subprocess.CalledProcessError:
            print(f"FAILED: {rec['label']}", file=sys.stderr)
            failed += 1

    target = f" into keyring {args.keyring!r}" if args.keyring else ""
    print(
        f"Done: imported {imported} item(s) from {args.dump_file}{target} "
        f"({failed} failed)"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
