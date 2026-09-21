#!/bin/bash

# ============================================================
# Linux System Maintenance Script
#
# Intended for Debian/Ubuntu-based systems using APT.
#
# Usage:
#   sudo ./maintenance.sh
#   sudo ./maintenance.sh --cleanup
#   ./maintenance.sh --help
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

LOCK_FILE="/run/system-maintenance.lock"

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

show_help() {
    cat <<EOF
Linux System Maintenance Script

Usage:
    sudo ./maintenance.sh [OPTION]

Options:
    --cleanup    Perform maintenance and remove unused packages
                 and obsolete package archives.

    --help       Display this help message.

Default operation:
    Update package lists and perform a full system upgrade.

Examples:
    sudo ./maintenance.sh
    sudo ./maintenance.sh --cleanup
    ./maintenance.sh --help
EOF
}

# ------------------------------------------------------------
# Parse command-line arguments
# ------------------------------------------------------------

CLEANUP=false

if [[ $# -gt 1 ]]; then
    error_exit "Too many arguments. Use --help for usage information."
fi

if [[ $# -eq 1 ]]; then
    case "$1" in
        --cleanup)
            CLEANUP=true
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo
            show_help >&2
            exit 1
            ;;
    esac
fi

# ------------------------------------------------------------
# Check root privileges
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    error_exit "Please run this script as root (for example: sudo ./maintenance.sh)."
fi

# ------------------------------------------------------------
# Check that apt-get is installed
# ------------------------------------------------------------

if ! command -v apt-get >/dev/null 2>&1; then
    error_exit "apt-get was not found on this system. This script requires a Debian/Ubuntu-style APT package manager."
fi

# ------------------------------------------------------------
# Prevent simultaneous executions
# ------------------------------------------------------------

exec 9>"$LOCK_FILE"

if ! flock -n 9; then
    error_exit "Another system maintenance process is already running."
fi

# ------------------------------------------------------------
# Display startup information
# ------------------------------------------------------------

echo "======================================"
echo " Starting System Maintenance"
echo "======================================"
echo

if [[ "$CLEANUP" == true ]]; then
    echo "Mode: Maintenance + cleanup"
else
    echo "Mode: Standard maintenance"
fi

echo

# ------------------------------------------------------------
# 1. Update package lists
# ------------------------------------------------------------

if [[ "$CLEANUP" == true ]]; then
    echo "[1/4] Updating package lists..."
else
    echo "[1/2] Updating package lists..."
fi

apt-get update

echo

# ------------------------------------------------------------
# 2. Perform full system upgrade
# ------------------------------------------------------------

if [[ "$CLEANUP" == true ]]; then
    echo "[2/4] Performing full system upgrade..."
else
    echo "[2/2] Performing full system upgrade..."
fi

apt-get full-upgrade -y

echo

# ------------------------------------------------------------
# 3 & 4. Optional cleanup
# ------------------------------------------------------------

if [[ "$CLEANUP" == true ]]; then

    echo "[3/4] Removing unused packages..."

    apt-get autoremove -y

    echo

    echo "[4/4] Cleaning obsolete package archives..."

    apt-get autoclean

    echo
fi

# ------------------------------------------------------------
# Check whether a reboot is required
# ------------------------------------------------------------

if [[ -f /var/run/reboot-required ]]; then
    echo "WARNING: A reboot is required."
    echo
fi

# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------

echo "======================================"
echo " Maintenance Complete"
echo "======================================"
