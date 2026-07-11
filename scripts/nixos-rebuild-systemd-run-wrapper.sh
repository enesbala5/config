#!/usr/bin/env bash
# Used on PATH ahead of real systemd-run while nixos-rebuild runs inside our
# surviving nixos-rebuild-switch unit.
#
# nixos-rebuild-ng wraps switch-to-configuration in `systemd-run --pipe`. That
# nested unit is unnecessary when we already provide survival, and --pipe breaks
# when the parent dies / over flaky SSH. Exec activation directly instead.
set -euo pipefail

real_systemd_run=/run/current-system/sw/bin/systemd-run

is_activation_wrap=false
for arg in "$@"; do
    case "$arg" in
        --unit=nixos-rebuild-switch-to-configuration | --unit=nixos-rebuild-switch-to-configuration.service)
            is_activation_wrap=true
            break
            ;;
    esac
done

if [ "$is_activation_wrap" != true ]; then
    exec "$real_systemd_run" "$@"
fi

cmd=()
skip_next=false
for arg in "$@"; do
    if [ "$skip_next" = true ]; then
        skip_next=false
        continue
    fi
    case "$arg" in
        -E)
            # Next arg is the env var name to passthrough (already in our env).
            skip_next=true
            continue
            ;;
        --collect | --no-ask-password | --pipe | --quiet | --service-type=* | --unit=*)
            continue
            ;;
        -*)
            # Unknown systemd-run flag; skip rather than treating as command.
            continue
            ;;
    esac
    cmd+=("$arg")
done

if [ "${#cmd[@]}" -eq 0 ]; then
    echo "nixos-rebuild-systemd-run-wrapper: could not find activation command in:" "$@" >&2
    exec "$real_systemd_run" "$@"
fi

# Match nixos-rebuild-ng's -E LOCALE_ARCHIVE / -E NIXOS_INSTALL_BOOTLOADER passthrough
export LOCALE_ARCHIVE="${LOCALE_ARCHIVE-}"
export NIXOS_INSTALL_BOOTLOADER="${NIXOS_INSTALL_BOOTLOADER:-0}"

exec "${cmd[@]}"
