#!/usr/bin/env bash
# Daily restic backup of ~/.hermes from the Hermes Agent VM.
# Pulls the directory over Incus REST (tar + files API), then restic to R2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/incus-rest.sh"

VM_NAME="${VM_NAME:-hermes-agent}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/hermes-agent-secrets}"
NOTIFY="${NOTIFY:-${SCRIPT_DIR}/../telegram/notify.sh}"

if [[ -f "$SECRETS_PATH" ]]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "$SECRETS_PATH"
  set +o allexport
fi

if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
  echo "Error: RESTIC_REPOSITORY and RESTIC_PASSWORD must be set (via $SECRETS_PATH)" >&2
  exit 1
fi

if ! incus_instance_exists "$VM_NAME"; then
  echo "Error: VM ${VM_NAME} does not exist" >&2
  exit 1
fi

status="$(incus_instance_status "$VM_NAME" || true)"
if [[ "$status" != "Running" ]]; then
  echo "Error: VM ${VM_NAME} is not running (status: ${status:-unknown})" >&2
  exit 1
fi

notify_failure() {
  if [[ -x "$NOTIFY" ]]; then
    TOKEN="${OPS_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
    CHAT="${OPS_TELEGRAM_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
    if [[ -n "$TOKEN" && -n "$CHAT" ]]; then
      "$NOTIFY" -t "$TOKEN" -c "$CHAT" -m md \
        "Hermes backup failed on ${VM_NAME}: $1" || true
    fi
  fi
}

TMP="$(mktemp -d)"
TAR="$TMP/hermes.tar"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "==> Pulling /root/.hermes from ${VM_NAME}..."
if ! incus_dir_pull_tar "$VM_NAME" /root/.hermes "$TAR"; then
  notify_failure "Failed to pull /root/.hermes"
  exit 1
fi

mkdir -p "$TMP/restore"
tar -C "$TMP/restore" -xf "$TAR"

if [[ ! -d "$TMP/restore/.hermes" ]]; then
  notify_failure "Pulled archive did not contain .hermes/"
  exit 1
fi

echo "==> restic backup..."
if ! restic backup "$TMP/restore/.hermes" --tag hermes-agent --tag automated; then
  notify_failure "restic backup returned non-zero"
  exit 1
fi

if ! restic forget --keep-daily 7 --keep-weekly 4 --prune; then
  notify_failure "restic forget --prune returned non-zero"
  exit 1
fi

echo "==> Backup complete."
