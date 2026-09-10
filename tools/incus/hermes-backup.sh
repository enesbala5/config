#!/usr/bin/env bash
# Daily restic backup of ~/.hermes from the Hermes Agent VM (incus CLI).
set -euo pipefail

VM_NAME="${VM_NAME:-hermes-agent}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/hermes-agent-secrets}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY="${NOTIFY:-${SCRIPT_DIR}/../telegram/notify.sh}"

if [[ -f "$SECRETS_PATH" ]]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "$SECRETS_PATH"
  set +o allexport
fi

if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
  echo "Error: RESTIC_REPOSITORY and RESTIC_PASSWORD must be set" >&2
  exit 1
fi

notify_failure() {
  if [[ -x "$NOTIFY" ]]; then
    TOKEN="${OPS_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
    CHAT="${OPS_TELEGRAM_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"
    if [[ -n "$TOKEN" && -n "$CHAT" ]]; then
      "$NOTIFY" -t "$TOKEN" -c "$CHAT" -m md "Hermes backup failed on ${VM_NAME}: $1" || true
    fi
  fi
}

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

if ! incus file pull --recursive "${VM_NAME}/root/.hermes" "$TMP/"; then
  notify_failure "Failed to pull /root/.hermes"
  exit 1
fi

SRC="$TMP/.hermes"
[[ -d "$SRC" ]] || SRC="$TMP/hermes"
if [[ ! -d "$SRC" ]]; then
  notify_failure "Pulled tree did not contain .hermes/"
  exit 1
fi

restic backup "$SRC" --tag hermes-agent --tag automated || { notify_failure "restic backup failed"; exit 1; }
restic forget --keep-daily 7 --keep-weekly 4 --prune || { notify_failure "restic forget failed"; exit 1; }
echo "==> Backup complete."
