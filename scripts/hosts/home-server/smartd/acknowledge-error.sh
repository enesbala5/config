#!/usr/bin/env bash
# Append a smartd ack id (SERIAL:FAILTYPE) to /var/tmp/smartd-acknowledged.
# Run this on home-server after copying the id from the Telegram button.
set -euo pipefail

ACK_FILE="${SMARTD_ACK_FILE:-/var/tmp/smartd-acknowledged}"

usage() {
  echo "Usage: $0 \"SERIAL:FailType\"" >&2
  echo "Example: $0 \"5VJ994TE:CurrentPendingSector\"" >&2
  exit 1
}

[[ $# -eq 1 && -n "${1:-}" ]] || usage

key="$1"
key="${key#"${key%%[![:space:]]*}"}"
key="${key%"${key##*[![:space:]]}"}"
[[ -n "$key" ]] || usage

if [[ "$key" == *$'\n'* ]]; then
  echo "Error: ack id must be a single line" >&2
  exit 1
fi

if [[ -f "$ACK_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == "$key" ]]; then
      echo "Already acknowledged: $key"
      exit 0
    fi
  done < "$ACK_FILE"
fi

printf '%s\n' "$key" >> "$ACK_FILE"
echo "Acknowledged: $key"
echo "Written to $ACK_FILE"
