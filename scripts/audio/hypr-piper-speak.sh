#!/usr/bin/env bash
# hypr-piper-speak.sh — speak the Wayland selection with Piper.
#
# Usage:
#   hypr-piper-speak.sh -l en|sq   speak with that voice
#   hypr-piper-speak.sh            pick language (fzf in a terminal, else vicinae)
#   hypr-piper-speak.sh stop       stop playback

set -u

VOICE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/piper-voices"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-piper-speak.pid"
MPV_TITLE="hypr-piper-tts"
HF_BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main"

if command -v piper-tts >/dev/null 2>&1; then
    PIPER_BIN=piper-tts
else
    PIPER_BIN="/etc/profiles/per-user/${USER}/bin/piper"
fi

LANG_CODE=""
MODE=""

usage() {
    printf '%s\n' \
        "Usage: hypr-piper-speak.sh [-l en|sq] | stop" \
        "  -l, --language en|sq   English (amy) or Albanian (edon)" \
        "  (no -l)                pick: fzf if stdout is a TTY, else vicinae dmenu" \
        "  stop                   stop playback"
}

notify() {
    notify-send "Piper TTS" "$@"
}

is_speaking() {
    pgrep -f "mpv --title=${MPV_TITLE}" >/dev/null 2>&1 && return 0
    pgrep -f "${PIPER_BIN} --model " >/dev/null 2>&1
}

stop_playback() {
    if [[ -f "$PID_FILE" ]]; then
        kill "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    pkill -f "mpv --title=${MPV_TITLE}" 2>/dev/null || true
    pkill -f "${PIPER_BIN} --model " 2>/dev/null || true
}

voice_for() {
    case "$1" in
        en)
            VOICE_NAME="en_US-amy-medium"
            VOICE_HF_PATH="en/en_US/amy/medium"
            ;;
        sq)
            VOICE_NAME="sq_AL-edon-medium"
            VOICE_HF_PATH="sq/sq_AL/edon/medium"
            ;;
        *)
            return 1
            ;;
    esac
    MODEL="${VOICE_DIR}/${VOICE_NAME}.onnx"
    MODEL_JSON="${MODEL}.json"
}

pick_language() {
    local line
    local options=$'Albanian (sq)\nEnglish (en)'
    if [[ -t 1 ]] && command -v fzf >/dev/null 2>&1; then
        line="$(printf '%s\n' "$options" | fzf --prompt='TTS language> ')" || true
    elif command -v vicinae >/dev/null 2>&1; then
        line="$(printf '%s\n' "$options" | vicinae dmenu --placeholder "TTS language")" || true
    else
        notify "Pass -l en or -l sq (no fzf/vicinae)"
        return 1
    fi
    [[ -z "${line:-}" ]] && return 1
    if [[ "$line" =~ \((en|sq)\) ]]; then
        LANG_CODE="${BASH_REMATCH[1]}"
        return 0
    fi
    notify "Unknown language: ${line}"
    return 1
}

ensure_voice() {
    mkdir -p "$VOICE_DIR"
    if [[ -f "$MODEL" && -f "$MODEL_JSON" ]]; then
        return 0
    fi

    notify "Downloading ${VOICE_NAME} voice…"
    if ! curl -fsSL "${HF_BASE}/${VOICE_HF_PATH}/${VOICE_NAME}.onnx" -o "$MODEL"; then
        notify "Failed to download voice model"
        return 1
    fi
    if ! curl -fsSL "${HF_BASE}/${VOICE_HF_PATH}/${VOICE_NAME}.onnx.json" -o "$MODEL_JSON"; then
        notify "Failed to download voice config"
        return 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        stop)
            MODE=stop
            shift
            ;;
        -l | --language)
            LANG_CODE="${2:-}"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            notify "Unknown option: $1"
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "$MODE" == "stop" ]]; then
    if is_speaking || [[ -f "$PID_FILE" ]]; then
        stop_playback
        notify "TTS Stopped"
    fi
    exit 0
fi

if [[ -z "$LANG_CODE" ]]; then
    pick_language || exit 0
fi

if ! voice_for "$LANG_CODE"; then
    notify "Language must be en or sq (got ${LANG_CODE})"
    exit 1
fi

text="$(wl-paste -p 2>/dev/null || true)"
if [[ -z "${text//[[:space:]]/}" ]]; then
    text="$(wl-paste 2>/dev/null || true)"
fi
if [[ -z "${text//[[:space:]]/}" ]]; then
    notify "No text selected"
    exit 1
fi

ensure_voice || exit 1
stop_playback

preview="$(printf '%s' "$text" | tr '\n' ' ')"
if [[ ${#preview} -gt 80 ]]; then
    preview="${preview:0:80}…"
fi
notify "${LANG_CODE}: ${preview}"

printf '%s\n' "$text" | "$PIPER_BIN" --model "$MODEL" -f - \
    | mpv --no-terminal --force-window=no --audio-display=no \
        --title="$MPV_TITLE" \
        --no-video \
        --gapless-audio=no \
        --no-resume-playback - &
echo $! >"$PID_FILE"
