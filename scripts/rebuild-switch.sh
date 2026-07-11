#!/usr/bin/env bash

# A rebuild script that commits on a successful build
set -e
set -o pipefail

# Parse command line arguments
SKIP_CHECK=false
SHOW_TRACE=false
NO_COMMIT=true
HOSTNAME=""

show_help() {
    echo "Usage: $0 [OPTIONS] <hostname>"
    echo ""
    echo "A rebuild script that commits on a successful build."
    echo ""
    echo "Arguments:"
    echo "  hostname          The name of your NixOS hostname (required)"
    echo "                    Examples: 'framework-13', 'home-server'"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message and exit"
    echo "  -f, --force       Skip checking for changes before rebuilding"
    echo "                    Also required when git or nixfmt are not installed"
    echo "  --show-trace      Show detailed error traces during rebuild"
    echo "  --commit          Commit changes after a successful rebuild"
    echo ""
    echo "Examples:"
    echo "  $0 framework-13"
    echo "  $0 --force framework-13"
    echo "  $0 -f home-server"
    echo "  $0 --show-trace framework-13"
    echo "  $0--commit framework-13"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            SKIP_CHECK=true
            shift
            ;;
        --show-trace)
            SHOW_TRACE=true
            shift
            ;;
       --commit)
            NO_COMMIT=false
            shift
            ;;
        -*)
            echo "Error: Unknown option $1"
            echo ""
            show_help
            exit 1
            ;;
        *)
            if [ -z "$HOSTNAME" ]; then
                HOSTNAME="$1"
            else
                echo "Error: Multiple hostnames provided. Only one hostname is expected."
                echo ""
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if hostname parameter is provided
if [ -z "$HOSTNAME" ]; then
    echo "Error: Hostname parameter is required."
    echo ""
    show_help
    exit 1
fi

# Check tool availability
HAS_GIT=false
HAS_NIXFMT=false

if command -v git >/dev/null 2>&1; then
    HAS_GIT=true
fi

if command -v nixfmt >/dev/null 2>&1; then
    HAS_NIXFMT=true
fi

# Validate --force requirement for missing tools
if [ "$HAS_GIT" = false ]; then
    if [ "$SKIP_CHECK" = false ]; then
        echo "Error: Git is not installed on this system."
        echo "Please use --force or -f to rebuild without git tracking."
        echo ""
        show_help
        exit 1
    fi
fi

if [ "$HAS_NIXFMT" = false ]; then
    if [ "$SKIP_CHECK" = false ]; then
        echo "Error: nixfmt is not installed on this system."
        echo "Please use --force or -f to rebuild without formatting and commit tracking."
        echo ""
        show_help
        exit 1
    fi
fi

# Change to your NixOS configuration directory
pushd ~/config/nix/nixos/

# Early return if no changes were detected (unless --force flag is used)
if [ "$HAS_GIT" = true ] && [ "$SKIP_CHECK" = false ]; then
    if git diff --quiet '*.nix'; then
        echo "No changes detected, exiting."
        echo "Use --force or -f to skip this check and rebuild anyway."
        popd
        exit 0
    fi
fi

# Format Nix files using nixfmt (nixfmt-rfc-style)
if [ "$HAS_NIXFMT" = true ]; then
    echo "--------------------------------------"
    echo "Formatting Nix files..."
    nixfmt *.nix || (echo "Formatting failed!" && exit 1)

    # Show changes after formatting
    if [ "$HAS_GIT" = true ]; then
        git diff -U0 '*.nix'
    fi
fi

echo "--------------------------------------"
echo "NixOS Rebuilding..."
echo "--------------------------------------"

# Get sudo authentication early
sudo echo "--------------------------------------" && echo "Starting rebuild..."

# Rebuild NixOS, stream output in real-time while also saving to log file
# On error, show highlighted errors from the log
REBUILD_ARGS=("nixos-rebuild" "switch" "--impure" "--flake" "${HOME}/config/nix/nixos/#${HOSTNAME}")
if [ "$SHOW_TRACE" = true ]; then
    REBUILD_ARGS+=("--show-trace")
fi

# When running over SSH, wrap in systemd-run so the rebuild survives sshd
# restarting mid-activation (which would otherwise kill this SSH session and
# leave docker.socket / other units never started).
#
# systemd-run starts a clean root env (HOME=/root). Nix then fetches the flake
# via git+file:// and refuses /home/e/config because it is owned by us, not
# root. Normal `sudo` keeps HOME=/home/e so this never shows up. Write
# safe.directory into /root/.gitconfig explicitly (not via --global — NixOS
# sudo preserves HOME and would write to the wrong file).
if [ -n "${SSH_CONNECTION:-}" ]; then
    echo "SSH session detected — running via systemd-run to survive sshd restart"
    echo "(if connection drops, reconnect and run: journalctl -fu nixos-rebuild-switch)"
    echo "--------------------------------------"
    sudo git config --file /root/.gitconfig --add safe.directory "${HOME}/config"
    sudo systemd-run \
        --unit=nixos-rebuild-switch \
        --collect \
        --wait \
        --pty \
        --setenv=HOME=/root \
        "${REBUILD_ARGS[@]}" 2>&1 | tee nixos-switch.log || {
        echo ""
        echo "--------------------------------------"
        echo "Build failed! Errors:"
        echo "--------------------------------------"
        grep --color error nixos-switch.log || true
        exit 1
    }
else
    sudo "${REBUILD_ARGS[@]}" 2>&1 | tee nixos-switch.log || {
        echo ""
        echo "--------------------------------------"
        echo "Build failed! Errors:"
        echo "--------------------------------------"
        grep --color error nixos-switch.log || true
        exit 1
    }
fi

# Get current generation metadata and commit changes (only if both git and nixfmt are available)
if [ "$HAS_GIT" = true ] && [ "$HAS_NIXFMT" = true ] && [ "$NO_COMMIT" = false ]; then
    current=$(nixos-rebuild list-generations | grep -i current)
    echo "--------------------------------------"
    echo "Commiting Changes..."
    echo "--------------------------------------"
    # Commit all changes with the generation metadata
    # Use || true to prevent script exit when there's nothing to commit
    git commit -am "$current" || true
fi

# Return to the original directory
popd || true

message="NixOS Rebuilt OK!"

echo "--------------------------------------"
echo "$message"
echo "--------------------------------------"
# Notify that the rebuild was successful
notify-send "NixOS Rebuild" "$message" --icon=software-update-available || true
