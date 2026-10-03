#!/usr/bin/env bash
# Push the contents of a local directory into a running Incus VM.
#
# Shared by the *-vm-manage.sh lifecycle scripts so skills (and any other
# directory tree) are synced the same way everywhere.
#
# Usage:
#   VM_NAME=<instance> push-files.sh <source_folder> <dest_folder_inside_vm>
#
# Copies everything under <source_folder> into <dest_folder_inside_vm> in the
# guest, preserving the directory structure and file modes and owning the
# result as root:root. The instance is taken from $VM_NAME.
#
# The source is passed as "<source>/.", which incus treats as "the directory's
# contents" rather than creating a nested copy of the directory itself.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: VM_NAME=<instance> $0 <source_folder> <dest_folder_inside_vm>" >&2
  exit 2
fi

SRC="$1"
DEST="${2#/}"
VM_NAME="${VM_NAME:?VM_NAME must name the target Incus instance}"

if [[ ! -d "$SRC" ]]; then
  echo "Warning: ${SRC} not found; skipping push to ${VM_NAME}:/${DEST}." >&2
  exit 0
fi

echo "==> Pushing ${SRC} -> ${VM_NAME}:/${DEST}"
incus exec "$VM_NAME" -- mkdir -p "/${DEST}"
incus file push -r --create-dirs --uid 0 --gid 0 \
  "${SRC}/." "${VM_NAME}/${DEST}"
