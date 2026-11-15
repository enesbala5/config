#!/usr/bin/env bash
# Mount the host recording directory into an Incus guest at the same path.
set -euo pipefail

VM_NAME="${1:?usage: attach-helium-recordings.sh <vm-name>}"
SRC="${HELIUM_RECORDINGS:-/var/lib/helium-browser/recordings}"
OWNER="${HELIUM_OWNER:-e}"

if ! incus info "$VM_NAME" >/dev/null 2>&1; then
  echo "Skipping recording mount: ${VM_NAME} does not exist yet"
  exit 0
fi

if [[ "$(id -u)" -eq 0 ]]; then
  install -d -m 0755 -o "$OWNER" -g users "$SRC"
else
  install -d -m 0755 "$SRC"
fi

if incus config device get "$VM_NAME" helium-recordings source >/dev/null 2>&1; then
  current="$(incus config device get "$VM_NAME" helium-recordings source)"
  if [[ "$current" != "$SRC" ]]; then
    incus config device set "$VM_NAME" helium-recordings source="$SRC"
  fi
  exit 0
fi

# VM agent mounts this virtiofs/9p share. A running guest sees it after restart.
incus config device add "$VM_NAME" helium-recordings disk \
  source="$SRC" \
  path="$SRC"
