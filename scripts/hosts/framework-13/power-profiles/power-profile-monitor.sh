#!/usr/bin/env bash
set -uo pipefail

# Monitors power profile changes and calls the handler script.

HANDLER="${HANDLER:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/power-profile-handler.sh}"
LOG_FILE="${LOG_FILE:-/tmp/power-profile-monitor.log}"
TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
TARGET_UID="$(id -u "${TARGET_USER}" 2>/dev/null || echo "")"

log() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >/dev/null
}

run_as_target_user() {
  if [[ -z "$TARGET_USER" || -z "$TARGET_UID" ]]; then
    log "Target user not set; skipping user action: $*"
    return 1
  fi

  # Build minimal session env for the user.
  local env_vars=(
    "XDG_RUNTIME_DIR=/run/user/${TARGET_UID}"
    "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${TARGET_UID}/bus"
  )

  # Provide best-effort display defaults for desktop notifications.
  if [[ -z "${WAYLAND_DISPLAY:-}" && -S "/run/user/${TARGET_UID}/wayland-1" ]]; then
    env_vars+=("WAYLAND_DISPLAY=wayland-1")
  fi
  if [[ -z "${DISPLAY:-}" ]]; then
    env_vars+=("DISPLAY=:0")
  fi

  sudo -u "$TARGET_USER" env "${env_vars[@]}" "$@"
}

send_notification() {
  local profile="${1:-}"
  [[ -z "$profile" ]] && return
  
  local message="Switched to: ${profile^}"

  if run_as_target_user notify-send "Power Profile" "$message" >/dev/null 2>&1; then
    log "Notification sent for profile ${profile}"
  else
    log "Notification failed for profile ${profile} (notify-send may not be available)"
  fi
}

apply_profile() {
  local profile="${1:-}"
  [[ -z "$profile" ]] && return
  
  # Skip if this is the same profile we just applied
  if [[ "$profile" == "$LAST_PROFILE" ]]; then
    return
  fi
  
  log "Applying profile: ${profile} (previous: ${LAST_PROFILE:-none})"
  
  # Send notification immediately
  send_notification "$profile"
  LAST_PROFILE="$profile"
  
  # Run handler in background so notification isn't delayed
  if /usr/bin/env bash "$HANDLER" "$profile"; then
    log "Handler completed successfully for profile '${profile}'"
  else
    log "Handler failed for profile '${profile}'"
		send_notification "Error applying profile: ${profile}. Please check the logs via power-profile-status"
  fi
}

current_profile() {
  powerprofilesctl get 2>/dev/null | tr -d '[:space:]' || true
}

monitor_dbus() {
  # Listen for PropertiesChanged signals and extract ActiveProfile from both UPower and hadess paths.
  # Format: signal line with path, then "string ActiveProfile", then "variant string "profile""
  log "Starting dbus-monitor for PropertiesChanged signals"
  dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" 2>&1 | \
  while IFS= read -r line; do
    # Detect signal line with power profiles path
    if [[ "$line" == *"path=/net/hadess/PowerProfiles"* ]] || [[ "$line" == *"path=/org/freedesktop/UPower/PowerProfiles"* ]]; then
      log "Detected power profiles signal: ${line}"
      in_power_block=1
      active_seen=0
      continue
    fi

    # Skip lines until we're in a power profiles block
    [[ "${in_power_block:-0}" -eq 1 ]] || continue

    # Look for "string \"ActiveProfile\"" (with or without indentation)
    if [[ "$line" == *"string \"ActiveProfile\""* ]]; then
      log "Found ActiveProfile string: ${line}"
      active_seen=1
      continue
    fi

    # After ActiveProfile, look for the variant line with the actual profile value
    if [[ "${active_seen:-0}" -eq 1 ]]; then
      # Match: "variant             string "profile"" or "variant string "profile""
      if [[ "$line" =~ variant[[:space:]]+string[[:space:]]+\"([^\"]+)\" ]]; then
        profile="${BASH_REMATCH[1]}"
        # Skip if this is the same profile we just processed (deduplicate signals from both UPower and hadess)
        if [[ "$profile" != "$LAST_PROFILE" ]]; then
          log "DBus signal: ActiveProfile -> ${profile}"
          apply_profile "$profile"
        else
          log "Skipping duplicate DBus signal for ${profile}"
        fi
        # Reset state after handling
        unset in_power_block
        unset active_seen
      else
        log "Variant line didn't match pattern: ${line}"
      fi
    fi
  done
  log "dbus-monitor loop ended"
}

poll_profiles() {
  while true; do
    local profile
    profile=$(current_profile)
    [[ -n "$profile" ]] && apply_profile "$profile"
    sleep 30
  done
}

LAST_PROFILE=""

initial_profile=$(current_profile)
if [[ -n "$initial_profile" ]]; then
  log "Initial profile: ${initial_profile}"
  apply_profile "$initial_profile"
else
  log "Could not detect initial power profile"
fi

if command -v dbus-monitor >/dev/null 2>&1; then
  while true; do
    log "Starting DBus monitor for power profile changes"
    monitor_dbus
    log "DBus monitor stopped; retrying in 5 seconds"
    sleep 5
  done
else
  log "dbus-monitor not available; falling back to polling every 30s"
  poll_profiles
fi

