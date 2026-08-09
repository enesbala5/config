#!/usr/bin/env bash
set -uo pipefail

# Central handler for power profile changes.
# Accepts one argument: power-saver | balanced | performance.

PROFILE="${1:-}"
LOG_FILE="${LOG_FILE:-/tmp/power-profile-handler.log}"

# Target user for user-session actions (Hyprland, user units).
TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
TARGET_UID="$(id -u "${TARGET_USER}" 2>/dev/null || echo "")"

log() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >/dev/null
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    log "Root required for this action; skipping"
    return 1
  fi
}

run_as_target_user() {
  if [[ -z "$TARGET_USER" || -z "$TARGET_UID" ]]; then
    log "Target user not set; skipping user action: $*"
    return 1
  fi

  # Build environment for Wayland/Hyprland
  local env_vars=(
    "XDG_RUNTIME_DIR=/run/user/${TARGET_UID}"
    "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${TARGET_UID}/bus"
  )

  # Find Wayland display socket
  for socket in /run/user/${TARGET_UID}/wayland-*; do
    if [[ -S "$socket" ]]; then
      env_vars+=("WAYLAND_DISPLAY=$(basename "$socket")")
      break
    fi
  done

  sudo -u "$TARGET_USER" env "${env_vars[@]}" "$@"
}

toggle_cpu_governor() {
  local mode="${1:-}"
  local governor_list

  if [[ -z "$mode" ]]; then
    log "CPU governor not changed (no mode provided)"
    return
  fi

  require_root || return

  governor_list=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || true)
  if [[ -n "$governor_list" ]] && ! grep -qw "$mode" <<<"$governor_list"; then
    log "Governor '$mode' not available on this system (available: $governor_list)"
    return
  fi

  for governor_file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -f "$governor_file" ]] || continue
    if echo "$mode" >"$governor_file" 2>/dev/null; then
      log "Set $(basename "$(dirname "$governor_file")") governor to $mode"
    else
      log "Failed to set governor to $mode for $governor_file"
    fi
  done
}

run_hyprctl() {
  # Try --instance 0 first, fall back to default if it fails
  if ! run_as_target_user hyprctl --instance 0 "$@" >/dev/null 2>&1; then
    run_as_target_user hyprctl "$@" >/dev/null 2>&1
  fi
}

toggle_hyprland() {
  local mode="${1:-}"

  if ! command -v hyprctl >/dev/null 2>&1; then
    log "Hyprland CLI (hyprctl) not found; skipping Hyprland tweaks"
    return
  fi

  case "$mode" in
    power-saver)
      log "Optimizing Hyprland for $mode"
      run_hyprctl keyword misc:vfr true
      run_hyprctl keyword decoration:blur:enabled false
      run_hyprctl keyword decoration:blur:passes 0
      run_hyprctl keyword decoration:blur:size 0
      run_hyprctl keyword decoration:shadow:enabled false
      ;;
    balanced)
      log "Restoring Hyprland settings for $mode"
			run_hyprctl reload
      ;;
    *)
      # Reset to normal configuration via reload for performance mode
      log "Hyprland config reloaded for $mode"
      run_hyprctl reload
      ;;
  esac
}

toggle_wifi_power() {
  local mode="${1:-}" # on | off -> power_save on/off
  local interface

  if ! command -v iw >/dev/null 2>&1; then
    log "Command 'iw' not found; skipping WiFi power save toggle"
    return
  fi

  require_root || return

  interface=$(iw dev | awk '$1=="Interface"{print $2}' | head -1)
  if [[ -z "$interface" ]]; then
    log "No WiFi interface found; skipping WiFi power save toggle"
    return
  fi

  if iw dev "$interface" set power_save "$mode" >/dev/null 2>&1; then
    log "Set WiFi power_save=$mode on $interface"
  else
    log "Failed to set WiFi power_save=$mode on $interface"
  fi
}

toggle_bluetooth_power() {
  local mode="${1:-}" # on | off
  local connected_count

  if ! command -v bluetoothctl >/dev/null 2>&1; then
    log "Command 'bluetoothctl' not found; skipping Bluetooth toggle"
    return
  fi

  require_root || return

  if [[ "$mode" == "off" ]]; then
    connected_count=$(bluetoothctl devices Connected 2>/dev/null | wc -l | tr -d '[:space:]')
    if [[ "$connected_count" != "0" ]]; then
      log "Bluetooth stays on (connected devices: $connected_count)"
      return
    fi
  fi

  if bluetoothctl power "$mode" >/dev/null 2>&1; then
    log "Bluetooth power $mode"
  else
    log "Failed to turn Bluetooth $mode"
  fi
}

toggle_swap_swappiness() {
  local mode="${1:-}" # low | high
  local value

  case "$mode" in
    low) value=10 ;;
    high) value=60 ;;
    *) log "Unknown swappiness mode '$mode'"; return ;;
  esac

  require_root || return

  if sysctl -w "vm.swappiness=${value}" >/dev/null 2>&1; then
    log "Swappiness set to ${value}"
  else
    log "Failed to set swappiness to ${value}"
  fi

  # Persist across reboots when permissions allow.
  echo "vm.swappiness=${value}" >/etc/sysctl.d/99-power-profile.conf 2>/dev/null || \
    log "Could not persist swappiness to /etc/sysctl.d/99-power-profile.conf"
}

manage_user_unit() {
  local unit="${1:-}"
  local action="${2:-}"

  [[ -z "$unit" || -z "$action" ]] && return

  if run_as_target_user systemctl --user "$action" "$unit" >/dev/null 2>&1; then
    log "User unit ${unit}: ${action}"
  else
    log "User unit ${unit}: ${action} failed or not present"
  fi
}

manage_system_unit() {
  local unit="${1:-}"
  local action="${2:-}"

  [[ -z "$unit" || -z "$action" ]] && return

  require_root || return

  if systemctl "$action" "$unit" >/dev/null 2>&1; then
    log "System unit ${unit}: ${action}"
  else
    log "System unit ${unit}: ${action} failed or not present"
  fi
}

toggle_services() {
  local action="${1:-}" # start | stop

  manage_user_unit "teamviewer.service" "$action"
  manage_user_unit "urserver.service" "$action"

  manage_system_unit "ratbagd.service" "$action"
  manage_system_unit "cups.service" "$action"
  # Only stop/start the triggers; leave an in-flight rclone.service alone.
  manage_system_unit "rclone.timer" "$action"
  manage_system_unit "rclone.path" "$action"
}

apply_profile() {
  local profile="${1:-}"

  case "$profile" in
    power-saver)
      log "Switching to power-saver mode"
      toggle_cpu_governor "powersave"
      toggle_hyprland "power-saver"
      toggle_wifi_power "on"
      toggle_bluetooth_power "off"
      toggle_swap_swappiness "low"
      toggle_services "stop"
      log "Power-saver mode applied"
      ;;
    balanced)
      log "Switching to balanced mode"
      # CPU governor managed by amd_pstate automatically - don't override
			toggle_hyprland "balanced"
      toggle_wifi_power "off"
      toggle_bluetooth_power "on"
      toggle_swap_swappiness "high"
      toggle_services "start"
      log "Balanced mode applied"
      ;;
    performance)
      log "Switching to performance mode"
      # CPU governor managed by amd_pstate automatically - don't override
      toggle_hyprland "performance"
      toggle_wifi_power "off"
      toggle_bluetooth_power "on"
      toggle_swap_swappiness "high"
      toggle_services "start"
      log "Performance mode applied"
      ;;
    *)
      log "Unknown profile '${profile}'"
      return 1
      ;;
  esac
}

if [[ -z "$PROFILE" ]]; then
  log "No profile provided. Usage: $0 <power-saver|balanced|performance>"
  exit 1
fi

apply_profile "$PROFILE"

