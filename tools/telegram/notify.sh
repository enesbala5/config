#!/usr/bin/env bash
#
# Reusable Telegram notification helper.
# Default: Markdown (links like [text](url) work).
#
# Usage:
#   ./notify.sh -c CHAT_ID "Your message here"
#   ./notify.sh --chat-id CHAT_ID -m html "Message with <a href=\"https://x.com\">link</a>"
#
# Flags:
#   -t, --token TOKEN          Telegram bot token (optional if TELEGRAM_BOT_TOKEN is set)
#   -c, --chat-id ID           Telegram chat ID (optional if TELEGRAM_CHAT_ID is set)
#   -m, --mode md|html|plain   Parse mode (default: md)
#
# Env (fallbacks):
#   TELEGRAM_BOT_TOKEN         Used if -t/--token not provided
#   TELEGRAM_CHAT_ID           Used if -c/--chat-id not provided
#
# Both token and chat ID are required (from flags and/or env).

TOKEN_FROM_ENV="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID_FROM_ENV="${TELEGRAM_CHAT_ID:-}"

TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

PARSE_MODE=md
MESSAGE=
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--token)
      TELEGRAM_BOT_TOKEN="${2:?token required}"
      shift 2
      ;;
    -c|--chat-id)
      TELEGRAM_CHAT_ID="${2:?chat-id required}"
      shift 2
      ;;
    -m|--mode)
      PARSE_MODE="${2:-md}"
      shift 2
      ;;
    *)
      MESSAGE="$*"
      break
      ;;
  esac
done

# Apply env fallbacks if flags not passed
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$TOKEN_FROM_ENV}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-$CHAT_ID_FROM_ENV}"

# Require both token and chat ID (from flags or env)
if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
  echo "Usage: $(basename "$0") -t TOKEN -c CHAT_ID [-m md|html|plain] <message>" >&2
  echo "Error: both bot token and chat ID are required (use -t/-c or set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)" >&2
  exit 1
fi

if [[ -z "$MESSAGE" ]]; then
  echo "Usage: $(basename "$0") -t TOKEN -c CHAT_ID [-m md|html|plain] <message>" >&2
  exit 1
fi

MAX_ATTEMPTS=4
TIMEOUT=10

# Map flag to Telegram parse_mode (md → Markdown, html → HTML, plain → none)
TELEGRAM_PARSE_MODE=
case "$PARSE_MODE" in
  md)     TELEGRAM_PARSE_MODE=Markdown ;;
  html)   TELEGRAM_PARSE_MODE=HTML ;;
  plain)  ;;
  *)
    echo "Unknown mode: $PARSE_MODE (use md, html, or plain)" >&2
    exit 1
    ;;
esac

CURL_EXTRA=()
if [[ -n "$TELEGRAM_PARSE_MODE" ]]; then
  CURL_EXTRA+=(--data-urlencode "parse_mode=${TELEGRAM_PARSE_MODE}")
fi

send_message() {
  local extra=("${@}")
  curl -s -o /tmp/.tg_response -w "%{http_code}" \
    -m "$TIMEOUT" \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}" \
    "${extra[@]}"
}

for attempt in $(seq 1 $MAX_ATTEMPTS); do
  HTTP_STATUS=$(send_message "${CURL_EXTRA[@]}")

  if [ "$HTTP_STATUS" = "200" ]; then
    exit 0
  fi

  # Markdown parse error — retry immediately without parse mode
  if [ "$HTTP_STATUS" = "400" ] && [ "${#CURL_EXTRA[@]}" -gt 0 ]; then
    echo "Markdown parse rejected (400), retrying as plain text..." >&2
    HTTP_STATUS=$(send_message)
    if [ "$HTTP_STATUS" = "200" ]; then
      exit 0
    fi
  fi

  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    sleep $((attempt * 2))
  fi
done

echo "Failed to send Telegram notification after $MAX_ATTEMPTS attempts (last HTTP status: $HTTP_STATUS)" >&2
exit 1
