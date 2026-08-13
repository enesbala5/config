#!/usr/bin/env bash
#
# Reusable Telegram notification helper.
# Default: Markdown (links like [text](url) work).
#
# Usage:
#   ./notify.sh -c CHAT_ID "Your message here"
#   ./notify.sh --chat-id CHAT_ID -m html "Message with <a href=\"https://x.com\">link</a>"
#   ./notify.sh --button url "https://example.com/u/1" "👤 *New user*"
#   ./notify.sh -m plain --button copy "5VJ994TE:CurrentPendingSector" "smartd alert"
#
# Buttons and text go in the same invocation: flags first (including
# --button), then the message as the remaining argument. One Telegram
# sendMessage is sent with both text and reply_markup.
#
#   telegram-notify -m plain \
#     --button copy "$key" \
#     "⚠️ smartd on ${hostname}
# 💾 Device: ${SMARTD_DEVICESTRING:-unknown device}
# 🏷️ Type: ${failtype}
# 🔑 ${key}
#
# ${SMARTD_FULLMESSAGE:-${SMARTD_MESSAGE:-no message}}"
#
# Flags:
#   -t, --token TOKEN          Telegram bot token (optional if TELEGRAM_BOT_TOKEN is set)
#   -c, --chat-id ID           Telegram chat ID (optional if TELEGRAM_CHAT_ID is set)
#   -m, --mode MODE            Parse mode (default: md)
#                              md | markdown     → Markdown
#                              md2 | markdownv2  → MarkdownV2
#                              html              → HTML
#                              plain             → none
#   --button TYPE MESSAGE      Button on the current row (repeatable)
#                              copy → clipboard (label and payload are MESSAGE)
#                              url  → open MESSAGE as a link (label: Open)
#                              Combine with a trailing message to send both
#   --new-row                  Start a new button row
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
BUTTON_ROWS=()
CURRENT_ROW=()

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

join_commas() {
  local IFS=,
  printf '%s' "$*"
}

flush_button_row() {
  if [[ ${#CURRENT_ROW[@]} -eq 0 ]]; then
    return 0
  fi
  BUTTON_ROWS+=("[$(join_commas "${CURRENT_ROW[@]}")]")
  CURRENT_ROW=()
}

add_button() {
  local type=$1 message=$2
  case "$type" in
    copy)
      CURRENT_ROW+=("{\"text\":\"$(json_escape "$message")\",\"copy_text\":{\"text\":\"$(json_escape "$message")\"}}")
      ;;
    url|link)
      CURRENT_ROW+=("{\"text\":\"Open\",\"url\":\"$(json_escape "$message")\"}")
      ;;
    *)
      echo "Unknown button type: $type (use copy or url)" >&2
      exit 1
      ;;
  esac
}

usage() {
  echo "Usage: $(basename "$0") -t TOKEN -c CHAT_ID [-m md|md2|html|plain] [--button copy|url MESSAGE] [--new-row] <message>" >&2
}

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
    --button)
      add_button "${2:?button type required (copy or url)}" "${3:?button message required}"
      shift 3
      ;;
    --new-row)
      flush_button_row
      shift
      ;;
    *)
      MESSAGE="$*"
      break
      ;;
  esac
done

flush_button_row

# Apply env fallbacks if flags not passed
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$TOKEN_FROM_ENV}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-$CHAT_ID_FROM_ENV}"

if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
  usage
  echo "Error: both bot token and chat ID are required (use -t/-c or set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)" >&2
  exit 1
fi

if [[ -z "$MESSAGE" ]]; then
  usage
  exit 1
fi

MAX_ATTEMPTS=4
TIMEOUT=10

TELEGRAM_PARSE_MODE=
case "$PARSE_MODE" in
  md|markdown)         TELEGRAM_PARSE_MODE=Markdown ;;
  md2|markdownv2)      TELEGRAM_PARSE_MODE=MarkdownV2 ;;
  html)                TELEGRAM_PARSE_MODE=HTML ;;
  plain)               ;;
  *)
    echo "Unknown mode: $PARSE_MODE (use md, md2, html, or plain)" >&2
    exit 1
    ;;
esac

CURL_EXTRA=()
if [[ -n "$TELEGRAM_PARSE_MODE" ]]; then
  CURL_EXTRA+=(--data-urlencode "parse_mode=${TELEGRAM_PARSE_MODE}")
fi

MARKUP_EXTRA=()
if [[ ${#BUTTON_ROWS[@]} -gt 0 ]]; then
  MARKUP_EXTRA+=(--data-urlencode "reply_markup={\"inline_keyboard\":[$(join_commas "${BUTTON_ROWS[@]}")]}")
fi

send_message() {
  local extra=("${@}")
  curl -s -o /tmp/.tg_response -w "%{http_code}" \
    -m "$TIMEOUT" \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}" \
    "${MARKUP_EXTRA[@]}" \
    "${extra[@]}"
}

for attempt in $(seq 1 $MAX_ATTEMPTS); do
  HTTP_STATUS=$(send_message "${CURL_EXTRA[@]}")

  if [ "$HTTP_STATUS" = "200" ]; then
    exit 0
  fi

  # Parse-mode error — retry immediately as plain text (buttons stay)
  if [ "$HTTP_STATUS" = "400" ] && [ "${#CURL_EXTRA[@]}" -gt 0 ]; then
    echo "Parse mode rejected (400), retrying as plain text..." >&2
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
